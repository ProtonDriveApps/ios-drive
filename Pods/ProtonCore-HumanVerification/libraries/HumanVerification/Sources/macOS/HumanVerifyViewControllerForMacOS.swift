//
//  HumanVerifyViewControllerForMacOS.swift
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

#if os(macOS)

import AppKit
import WebKit
import ProtonCoreUIFoundations
import ProtonCoreFoundations
import ProtonCoreNetworking
import ProtonCoreObservability
import ProtonCoreServices
import ProtonCoreUtilities

protocol HumanVerifyViewControllerDelegate: AnyObject {
    func didDismissViewController()
    func didShowHelpViewController()
    func willReopenViewController()
    func didDismissWithError(code: Int, description: String)
    func emailAddressAlreadyTakenWithError(code: Int, description: String)
}

final class HumanVerifyViewController: NSViewController {

    // MARK: Outlets

    var webView: WKWebView!
    @IBOutlet weak var activityIndicator: NSProgressIndicator!
    @IBOutlet weak var helpButton: NSButton!
    @IBOutlet weak var bannerView: NSView!
    @IBOutlet weak var bannerBackground: NSTextField!
    @IBOutlet weak var bannerMessage: NSTextField!
    @IBOutlet weak var bannerButton: NSButton!

    // MARK: Properties

    private var appearanceObserver: NSKeyValueObservation?
    let userContentController = WKUserContentController()
    weak var delegate: HumanVerifyViewControllerDelegate?
    var viewModel: HumanVerifyViewModel!
    var viewTitle: String?
    var dispatchQueue: CompletionBlockExecutor = .asyncMainExecutor

    // MARK: View controller life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupObservers()
        configureUI()
        loadWebContent()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.styleMask = [.closable, .titled, .resizable]
        view.window?.minSize = NSSize(width: 400, height: 520)
        view.window?.maxSize = NSSize(width: 800, height: 800)
    }

    deinit {
        userContentController.removeAllUserScripts()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Actions

    @IBAction func helpAction(_ sender: Any) {
        delegate?.didShowHelpViewController()
    }

    @IBAction func bannerButtonPressed(_ sender: Any) {
        hideBannerView()
    }

    // MARK: Private interface

    private func configureUI() {
        title = viewTitle ?? HVTranslation.title.l10n
        startActivityIndicator()
        setupWebView()
    }

    private func setupWebView() {
        userContentController.add(WeaklyProxingScriptHandler(self), name: viewModel.scriptName)
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.userContentController = userContentController
        viewModel.setup(webViewConfiguration: webViewConfiguration)
        if #available(macOS 10.15, *) {
            webViewConfiguration.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        webViewConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isHidden = true
        view.subviews.insert(webView, at: 0)

        webView.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 11, *) {
            let layoutGuide = view.safeAreaLayoutGuide
            webView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor).isActive = true
            webView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor).isActive = true
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            webView.topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
        } else {
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        }
    }

    private var lastLoadingURL: String?

    private func loadWebContent() {
        URLCache.shared.removeAllCachedResponses()
        let requestObj = viewModel.getURLRequest
        lastLoadingURL = requestObj.url?.absoluteString
        webView.customUserAgent = "ipad"
        webView.load(requestObj)
    }

    private func startActivityIndicator() {
        activityIndicator?.startAnimation(self)
        activityIndicator?.isHidden = false
    }

    private func stopActivityIndicator() {
        activityIndicator?.stopAnimation(self)
        activityIndicator?.isHidden = true
    }

    private func setupObservers() {
        if #available(macOS 10.14, *) {
            appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
                self?.loadWebContent()
            }
        } else {
            // Fallback on earlier versions
        }
    }
}

// MARK: - WKWebViewDelegate

extension HumanVerifyViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webview: WKWebView, didFinish nav: WKNavigation!) {

        func updateWebViewBackground(_ webView: WKWebView) {
            if let color = ColorProvider.BackgroundNorm.usingColorSpace(.sRGB) {
                let hexColor = String(format: "#%02lX%02lX%02lX%02lX",
                                      lroundf(Float(color.redComponent * 255)),
                                      lroundf(Float(color.greenComponent * 255)),
                                      lroundf(Float(color.blueComponent * 255)),
                                      lroundf(Float(color.alphaComponent * 255)))
                webView.evaluateJavaScript("document.body.style.background = '\(hexColor)';")
            }
        }

        webView.evaluateJavaScript("document.body.style.background = 'none';")
        if #available(macOS 11.0, *) {
            NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
                updateWebViewBackground(webView)
            }
        } else if #available(macOS 10.14, *) {
            NSAppearance.current = NSApp.effectiveAppearance
            updateWebViewBackground(webView)
        } else {
            updateWebViewBackground(webView)
        }
        stopActivityIndicator()
    }

    func webView(_ webview: WKWebView, didCommit nav: WKNavigation!) {
        startActivityIndicator()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleFailedRequest(error: error)
    }

    func webView(_ webview: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        handleFailedRequest(error: error)
    }

    func handleFailedRequest(error: Error) {
        ObservabilityEnv.report(.humanVerificationScreenLoadTotal(status: .failed))
        webView.isHidden = false
        stopActivityIndicator()
        guard let loadingUrl = lastLoadingURL else { return }
        viewModel.shouldRetryFailedLoading(host: loadingUrl, error: error) { [weak self] in
            if $0 {
                self?.loadWebContent()
            } else {
                self?.presentNotification(type: .error, message: error.localizedDescription)
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
        NSWorkspace.shared.open(url)
        configuration.userContentController = userContentController
        return WKWebView(frame: .zero, configuration: configuration)
    }
}

extension HumanVerifyViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        viewModel.interpretMessage(message: message) { [weak self] type, notificationMessage in
            DispatchQueue.main.async { [weak self] in
                self?.presentNotification(type: type, message: notificationMessage)
            }
        } loadedMessage: {
            ObservabilityEnv.report(.humanVerificationScreenLoadTotal(status: .successful))
            DispatchQueue.main.async { [weak self] in
                self?.webView.isHidden = false
            }
        } errorHandler: { [weak self] error, shouldClose in
            self?.dispatchQueue.execute { [weak self] in
                if shouldClose {
                    if let code = error.responseCode {
                        switch code {
                        case APIErrorCode.humanVerificationAddressAlreadyTaken:
                            ObservabilityEnv.report(.humanVerificationOutcomeTotal(status: .addressAlreadyTaken))
                            self?.delegate?.emailAddressAlreadyTakenWithError(code: code, description: error.localizedDescription)
                        case APIErrorCode.invalidVerificationCode:
                            ObservabilityEnv.report(.humanVerificationOutcomeTotal(status: .invalidVerificationCode))
                            self?.delegate?.willReopenViewController()
                        default:
                            ObservabilityEnv.report(.humanVerificationOutcomeTotal(status: .failed))
                            self?.delegate?.didDismissWithError(code: code, description: error.localizedDescription)
                        }
                    }
                } else {
                    ObservabilityEnv.report(.humanVerificationOutcomeTotal(status: .failed))
                    self?.presentNotification(type: .error, message: error.localizedDescription)
                }
            }
        } completeHandler: { [weak self] method in
            let delay: TimeInterval = method.predefinedMethod == .captcha ? 1.0 : 0.0
            // for captcha method there is an additional artificial delay to see verification animation
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.dismiss(self)
            }
        }
    }

    private func presentNotification(type: NotificationType, message: String) {
        let backgroundColor: NSColor
        let textColor: NSColor
        switch type {
        case .error:
            backgroundColor = ColorProvider.SignalDanger
            textColor = ColorProvider.TextNorm
        case .warning:
            backgroundColor = ColorProvider.SignalWarning
            textColor = ColorProvider.TextNorm
        case .info:
            backgroundColor = ColorProvider.SignalInfo
            textColor = ColorProvider.TextNorm
        case .success:
            backgroundColor = ColorProvider.SignalSuccess
            textColor = ColorProvider.TextNorm
        }
        bannerBackground.layer?.cornerRadius = 8
        bannerBackground.backgroundColor = backgroundColor
        bannerMessage.textColor = textColor
        bannerMessage.stringValue = message
        bannerButton.attributedTitle = NSAttributedString(string: HVTranslation.ok_button.l10n,
                                                          attributes: [.foregroundColor: textColor])
        showBannerView()
    }

    private func showBannerView() {
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.allowsImplicitAnimation = true
            context.duration = 0.5
            self?.bannerView.isHidden = false
            self?.bannerView.animator().alphaValue = 1
        }
    }

    private func hideBannerView() {
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.allowsImplicitAnimation = true
            context.duration = 0.5
            self?.bannerView.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.bannerView.isHidden = true
        }
    }
}

extension HumanVerifyViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        delegate?.didDismissViewController()
    }
}

#endif
