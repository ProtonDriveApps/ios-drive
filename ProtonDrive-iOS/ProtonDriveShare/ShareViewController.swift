// Copyright (c) 2025 Proton AG
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

import UIKit
import PDLocalization
import PDCore
import PDCoreIOS
import ProtonCoreCryptoGoInterface
import ProtonCoreCryptoPatchedGoImplementation

class ShareViewController: UIViewController {
    private let dependencies = ShareDependencies()
    private var progressContainer: UIView?
    private var progressView: UIProgressView?
    private var progressLabel: UILabel?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { [weak self] in
            // Inherit MainActor from viewWillAppear
            guard let results = await self?.copyFile() else { return }
            self?.handle(results)
        }
    }

    @MainActor
    func openParentApp() {
        guard let url = URL(string: Constants.UniversalLink.shareExtension.rawValue) else { return }

        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                Log.debug("Switch to main app", domain: .shareExtension)
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }
        extensionContext?.completeRequest(returningItems: nil)
    }
}

// MARK: - Import files
extension ShareViewController {
    func loadInputItems() -> [NSItemProvider] {
        guard
            let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
            let attachments = extensionItem.attachments
        else { return [] }
        return attachments
    }

    /// - Returns: is success
    func copyFile() async -> [URLResult] {
        let attachments = loadInputItems()
        if attachments.isEmpty {
            extensionContext?.completeRequest(returningItems: nil)
            return []
        }
        let totalCount = attachments.count
        Log.debug("User shares \(totalCount) files", domain: .shareExtension)
        showProgress(totalCount: totalCount)

        var completedCount = 0

        let results = await withTaskGroup(of: URLResult.self) { group in
            for attachment in attachments {
                group.addTask {
                    await self.dependencies.loadResource.execute(with: attachment)
                }
            }
            var results: [URLResult] = []
            for await result in group {
                results.append(result)
                completedCount += 1
                await updateProgress(completedCount: completedCount, totalCount: totalCount)
            }
            return results
        }
        hideProgress()
        return results
    }

    @MainActor
    func handle(_ results: [URLResult]) {
        if results.isEmpty {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        var unsupportedCount = 0
        var otherFailedCount = 0
        var successCount = 0

        for result in results {
            switch result {
            case .success:
                successCount += 1
            case .failure(let error):
                if case NSItemProviderLoadResource.Errors.unsupportedHTML = error {
                    unsupportedCount += 1
                } else {
                    Log.error("Load shared item failed", error: error, domain: .shareExtension)
                    otherFailedCount += 1
                }
            }
        }

        if successCount == results.count {
            openParentApp()
        } else if unsupportedCount > 0 {
            // Assume the user can share only one URL at a time
            presentURLAlert(results: results)
        } else {
            presentImportAlert(results: results, failsCount: otherFailedCount)
        }
    }

    @MainActor
    private func presentURLAlert(results: [URLResult]) {
        let message = Localization.shareExt_alert_msg_save_link_as
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: Localization.shareExt_alert_action_textFile, style: .default) { [weak self] _ in
                self?.openParentApp()
            }
        )
        alert.addAction(
            UIAlertAction(title: Localization.general_cancel, style: .destructive) { [weak self] _ in
                let fm = FileManager.default
                for result in results {
                    if let error = result.error,
                       case let NSItemProviderLoadResource.Errors.unsupportedHTML(url) = error {
                        try? fm.removeItem(at: url)
                    }
                }
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
        present(alert, animated: true)
    }

    @MainActor
    private func presentImportAlert(results: [URLResult], failsCount: Int) {
        let allFailed = results.count == failsCount
        let file = Localization.file_plural_type_with_num(num: failsCount).lowercased()
        let error = results.first(where: { $0.error != nil })?.error?.localizedDescription ?? ""
        let message = Localization.file_pickup_error(files: file, error: error)

        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localization.general_ok, style: .default) { [weak self] _ in
            if allFailed {
                self?.extensionContext?.completeRequest(returningItems: nil)
            } else {
                self?.openParentApp()
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - Progress bar
extension ShareViewController {
    @MainActor
    private func showProgress(totalCount: Int) {
        if progressContainer != nil {
            updateProgress(completedCount: 0, totalCount: totalCount)
            return
        }
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        container.layer.cornerRadius = 12

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.textAlignment = .center
        label.text = "Loading 0 / \(totalCount)"

        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progress = 0

        let stack = UIStackView(arrangedSubviews: [label, progress])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8

        container.addSubview(stack)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            progress.widthAnchor.constraint(equalToConstant: 220)
        ])

        progressContainer = container
        progressView = progress
        progressLabel = label
    }

    @MainActor
    private func updateProgress(completedCount: Int, totalCount: Int) {
        guard totalCount > 0 else { return }
        let clampedCompleted = min(max(completedCount, 0), totalCount)
        progressView?.setProgress(Float(clampedCompleted) / Float(totalCount), animated: true)
        progressLabel?.text = "Loading \(clampedCompleted) / \(totalCount)"
    }

    @MainActor
    private func hideProgress() {
        progressContainer?.removeFromSuperview()
        progressContainer = nil
        progressView = nil
        progressLabel = nil
    }
}

final class ShareDependencies {
    let loadResource: NSItemProviderLoadResource
    let logConfigurator: LogsConfigurator

    init() {
        inject(cryptoImplementation: ProtonCoreCryptoPatchedGoImplementation.CryptoGoMethodsImplementation.instance)
        PDFileManager.configure(with: Constants.appGroup)
        PDFileManager.cleanShareTempFolder()
        loadResource = .init(copyURLFactory: { filename in
            PDFileManager.prepareShareTempURL(for: filename)
        })

        let defaultHost = Constants.clientApiConfig.environment.doh.defaultHost
        logConfigurator = LogsConfigurator(
            logSystem: .iOSShare,
            localSettings: LocalSettings.shared,
            defaultHost: defaultHost
        )
    }
}
