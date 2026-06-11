// Copyright (c) 2024 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import Combine
import PDCore
import PDCoreIOS
import WebKit
import PDUIComponents
import ProtonCoreUIFoundations

final class ProtonFileWebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKDownloadDelegate {
    private let viewModel: ProtonFileWebViewModelProtocol
    private let cookieStorage: HTTPCookieStorage
    private let actionsMenu: UIMenu
    private var scriptHandlers = [WKScriptMessageHandler]()
    private var titleObserver: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    private lazy var loadingView = ViewHosting {
        SpinnerTextView(text: "")
    }
    private lazy var webView = makeWebView()

    init(viewModel: ProtonFileWebViewModelProtocol, cookieStorage: HTTPCookieStorage, actionsMenu: UIMenu) {
        self.viewModel = viewModel
        self.cookieStorage = cookieStorage
        self.actionsMenu = actionsMenu
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cleanUp()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        subscribeToUpdates()
        viewModel.startLoading()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // This view doesn't have a show action, so the navigation-to-next-view case can be ignored
        viewModel.viewDisappear()
    }

    private func setupView() {
        view.backgroundColor = ColorProvider.BackgroundNorm
        view.addSubview(loadingView)
        loadingView.centerInSuperview()
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        let menuButton = UIBarButtonItem(image: IconProvider.threeDotsHorizontal, primaryAction: nil, menu: actionsMenu)
        menuButton.accessibilityLabel = "ProtonFileWebView.Button.MoreSingle"
        menuButton.tintColor = ColorProvider.IconNorm
        navigationItem.rightBarButtonItem = menuButton
    }

    private func handleState(_ state: ProtonFileWebViewState) {
        switch state {
        case .loading:
            loadingView.isHidden = false
            webView.isHidden = true
        case let .url(url):
            setupCookiesAndLoad(url)
        }
    }

    private func setupCookiesAndLoad(_ url: URL) {
        Task { [weak self] in
            await self?.cookieStorage.cookies?.forEach { cookie in
                await self?.webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
            self?.load(url)
        }
    }

    @MainActor
    private func load(_ url: URL) {
        loadingView.isHidden = true
        webView.isHidden = false
        let urlRequest = URLRequest(url: url)
        webView.load(urlRequest)
    }

    private func subscribeToUpdates() {
        viewModel.state
            .sink { [weak self] state in
                self?.handleState(state)
            }
            .store(in: &cancellables)
        viewModel.title
            .sink{ [weak self] title in
                self?.navigationItem.title = title
            }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanUp),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func cleanUp() {
        viewModel.cleanUp()
    }

    private func makeWebView() -> WKWebView {
        let userContentController = WKUserContentController()
        let logHandler = ProtonFileWebLoggingHandler(
            userContentController: userContentController,
            deleter: viewModel.deleter,
            identifier: .init(id: viewModel.identifier.linkId, volumeID: viewModel.identifier.volumeId)
        )
        scriptHandlers = [
            logHandler,
            ProtonFileWebPlatformHandler(userContentController: userContentController)
        ]
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        return webView
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {        
        Log.debug("Opening content in webview: \(navigationAction.navigationType.rawValue)", domain: .protonDocs)
        webView.load(navigationAction.request)
        return nil
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if navigationAction.shouldPerformDownload {
            Log.debug("Handling download: \(navigationAction.navigationType.rawValue)", domain: .protonDocs)
            return .download
        }

        guard let url = navigationAction.request.url else {
            return .allow
        }
        viewModel.reportPerformanceIfNeeded(url: url)

        if viewModel.isInternal(url: url) {
            // In case of internal url, proceed with loading in webview
            Log.info("Loading internal url", domain: .protonDocs)
            return .allow
        } else {
            // Otherwise open link in browser
            // This will apply to links inside a doc or any info pages outside of docs host
            Log.info("Opening external url", domain: .protonDocs)
            viewModel.openExternal(url: url)
            return .cancel
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        Log.error("Failed to load web navigation", error: error, domain: .protonDocs)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        Log.debug("Started download: \(download.description)", domain: .protonDocs)
        download.delegate = self
    }

    // MARK: - WKDownloadDelegate

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        return viewModel.makeCleartextURL(for: suggestedFilename)
    }

    func downloadDidFinish(_ download: WKDownload) {
        viewModel.openShare()
    }

    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
        Log.error("Failed to finish download", error: error, domain: .protonDocs)
        viewModel.handleDownloadError()
    }
}
