//
//  HumanVerifyViewController.swift
//  ProtonCore-HumanVerification - Created on 2/1/16.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import WebKit

import ProtonCore_CoreTranslation
import ProtonCore_Foundations
import ProtonCore_Networking
import ProtonCore_Observability
import ProtonCore_Services
import ProtonCore_UIFoundations
import ProtonCore_Utilities

protocol HumanVerifyViewControllerDelegate: AnyObject {
    func didDismissViewController()
    func didShowHelpViewController()
    func willReopenViewController()
    func didFinishViewController()
    func didDismissWithError(code: Int, description: String)
    func emailAddressAlreadyTakenWithError(code: Int, description: String)
}

// Delete this enum once iOS 11 support is dropped.
enum UserInterfaceStyle: Int {
    case unspecified = 0
    case light = 1
    case dark = 2

    @available(iOS 12, *)
    init(value: UIUserInterfaceStyle) {
        switch value {
        case .unspecified:
            self = .unspecified
        case .light:
            self = .light
        case .dark:
            self = .dark
        @unknown default:
            assertionFailure("Unrecognized UIUserInterfaceStyle: \(value)")
            self = .unspecified
        }
    }

    @available(iOS 12, *)
    static func != (lhs: UIUserInterfaceStyle, rhs: UserInterfaceStyle) -> Bool {
        lhs.rawValue != rhs.rawValue
    }
}

final class HumanVerifyViewController: UIViewController, AccessibleView {

    // MARK: Outlets

    var webView: WKWebView!
    @IBOutlet weak var helpBarButtonItem: UIBarButtonItem! {
        didSet {
            helpBarButtonItem.title = CoreString._hv_help_button
            helpBarButtonItem.tintColor = ColorProvider.BrandNorm
        }
    }
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView! {
        didSet {
            activityIndicator.color = ColorProvider.IconNorm
        }
    }

    @IBOutlet weak var closeBarButtonItem: UIBarButtonItem!

    // MARK: Properties
    private let userContentController = WKUserContentController()
    weak var delegate: HumanVerifyViewControllerDelegate?
    var viewModel: HumanVerifyViewModel!
    var isModalPresentation = true
    var viewTitle: String?
    var banner: PMBanner?
    var presentsBannerInsteadOfWebView = false
    var dispatchQueue: CompletionBlockExecutor = .asyncMainExecutor
    private lazy var currentInterfaceStyle: UserInterfaceStyle = .unspecified

    override var preferredStatusBarStyle: UIStatusBarStyle { darkModeAwarePreferredStatusBarStyle() }

    // MARK: View controller life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupObservers()
        configureUI()
        loadWebContent()
        generateAccessibilityIdentifiers()
        view.accessibilityIdentifier = "Human Verification view"
    }

    deinit {
        userContentController.removeAllUserScripts()
        NotificationCenter.default.removeObserver(self)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 12.0, *) {
            if UIApplication.shared.applicationState == .active {
                checkInterfaceStyle()
            }
        }
    }

    // MARK: Actions

    @IBAction func closeAction(_ sender: Any) {
        ObservabilityEnv.report(.humanVerificationOutcomeTotal(status: .canceled))
        delegate?.didDismissViewController()
    }

    @IBAction func helpAction(_ sender: Any) {
        delegate?.didShowHelpViewController()
    }

    // MARK: Private interface

    private func configureUI() {
        title = viewTitle ?? CoreString._hv_title
        if #available(iOS 12.0, *) {
            currentInterfaceStyle = .init(value: traitCollection.userInterfaceStyle)
        }
        closeBarButtonItem.tintColor = ColorProvider.IconNorm
        closeBarButtonItem.accessibilityLabel = "closeButton"
        updateTitleAttributes()
        view.backgroundColor = ColorProvider.BackgroundNorm
        closeBarButtonItem.image = isModalPresentation ? IconProvider.cross : IconProvider.arrowLeft
        setupWebView()
    }

    private func setupWebView() {
        userContentController.add(WeaklyProxingScriptHandler(self), name: viewModel.scriptName)
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.userContentController = userContentController
        viewModel.setup(webViewConfiguration: webViewConfiguration)
        if #available(iOS 13.0, *) {
            webViewConfiguration.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        webViewConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        view.addSubview(webView)
        view.bringSubviewToFront(activityIndicator)

        let layoutGuide = view.safeAreaLayoutGuide
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
    }

    private var lastLoadingURL: String?

    private func loadWebContent() {
        hideWebView(showActivityIndicator: true)
        URLCache.shared.removeAllCachedResponses()
        let requestObj = viewModel.getURLRequest
        lastLoadingURL = requestObj.url?.absoluteString
        webView.load(requestObj)
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            if #available(iOS 12.0, *) {
                self?.checkInterfaceStyle()
            }
        }
    }

    @available(iOS 12.0, *)
    private func checkInterfaceStyle() {
        if traitCollection.userInterfaceStyle != currentInterfaceStyle {
            loadWebContent()
            currentInterfaceStyle = .init(value: traitCollection.userInterfaceStyle)
        }
    }

    private func presentErrorWithoutWebView(message: String) {
        self.hideWebView(showActivityIndicator: false)
        self.banner?.dismiss()
        self.banner = PMBanner(message: message, style: PMBannerNewStyle.error, dismissDuration: Double.infinity) { [weak self] _ in
            self?.dismissErrorBanner()
        }
        self.banner?.addButton(icon: IconProvider.arrowsRotate) { [weak self] _ in
            self?.dismissErrorBanner()
        }
        self.banner?.show(at: .top, on: self)
        presentsBannerInsteadOfWebView = true
    }

    private func presentErrorOverWebView(message: String) {
        self.banner?.dismiss()
        self.banner = PMBanner(message: message, style: PMBannerNewStyle.error, dismissDuration: Double.infinity)
        self.banner?.addButton(text: CoreString._hv_ok_button) { [weak self] _ in
            self?.banner?.dismiss()
        }
        self.banner?.show(at: .top, on: self)
    }

    private func dismissErrorBanner() {
        presentsBannerInsteadOfWebView = false
        banner?.dismiss()
        loadWebContent()
    }

    private func presentSuccessBanner(message: String) {
        self.banner?.dismiss()
        self.banner = PMBanner(message: message, style: PMBannerNewStyle.success)
        self.banner?.show(at: .topCustom(.baner), on: self)
    }

    private func showWebView() {
        enableUserInteraction(for: webView)
        webView.isHidden = false
        activityIndicator?.stopAnimating()
    }

    private func hideWebView(showActivityIndicator: Bool) {
        webView.isHidden = true
        if showActivityIndicator {
            activityIndicator?.startAnimating()
        } else {
            activityIndicator?.stopAnimating()
        }
    }

    private func enableUserInteraction(for webView: WKWebView) {
        webView.window?.isUserInteractionEnabled = true
    }
}

// MARK: - WKWebViewDelegate

extension HumanVerifyViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        enableUserInteraction(for: webView)
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleFailedRequest(error)
    }

    func webView(_ webview: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        handleFailedRequest(error)
    }

    private func handleFailedRequest(_ error: Error) {
        ObservabilityEnv.report(.humanVerificationScreenLoadTotal(status: .failed))
        guard let loadingUrl = lastLoadingURL else { return }
        viewModel.shouldRetryFailedLoading(host: loadingUrl, error: error) { [weak self] in
            if $0 {
                self?.loadWebContent()
            } else {
                self?.presentErrorWithoutWebView(message: error.localizedDescription)
            }
        }
    }

    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        handleAuthenticationChallenge(
            didReceive: challenge,
            noTrustKit: PMAPIService.noTrustKit,
            trustKit: PMAPIService.trustKit,
            challengeCompletionHandler: completionHandler
        )
    }
}

extension HumanVerifyViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        UIApplication.openURLIfPossible(url)
        return WKWebView(frame: webView.frame, configuration: configuration)
    }
}

extension HumanVerifyViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        viewModel.interpretMessage(message: message, notificationMessage: { [weak self] type, message in
            self?.dispatchQueue.execute { [weak self] in
                if let self = self {
                    switch type {
                    case .success:
                        self.presentSuccessBanner(message: message)
                    case .error:
                        self.presentErrorOverWebView(message: message)
                    default:
                        break
                    }
                }
            }
        }, loadedMessage: { [weak self] in
            ObservabilityEnv.report(.humanVerificationScreenLoadTotal(status: .successful))
            self?.dispatchQueue.execute { [weak self] in
                if !(self?.presentsBannerInsteadOfWebView ?? false) {
                    self?.showWebView()
                }
            }
        }, errorHandler: { [weak self] error, shouldClose in
            self?.dispatchQueue.execute { [weak self] in
                if shouldClose {
                    if let code = error.responseCode {
                        switch code {
                        case APIErrorCode.humanVerificationAddressAlreadyTaken:
                            self?.delegate?.emailAddressAlreadyTakenWithError(code: code, description: error.localizedDescription)
                        case APIErrorCode.invalidVerificationCode:
                            self?.delegate?.willReopenViewController()
                        default:
                            ObservabilityEnv.report(.humanVerificationOutcomeTotal(status: .failed))
                            self?.delegate?.didDismissWithError(code: code, description: error.localizedDescription)
                        }
                    }
                } else {
                    ObservabilityEnv.report(.humanVerificationOutcomeTotal(status: .failed))
                    self?.presentErrorWithoutWebView(message: error.localizedDescription)
                }
            }
        }, completeHandler: { [weak self] method in
            let delay: DispatchTimeInterval = method.predefinedMethod == .captcha ? .seconds(1) : .seconds(0)
            // for captcha method there is an additional artificial delay to see verification animation
            self?.dispatchQueue.execute(after: delay) { [weak self] in
                self?.delegate?.didFinishViewController()
            }
        })
    }
}
