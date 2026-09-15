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

import Foundation
import UIKit
import SwiftUI
import StoreKit
import PDCore
import PDUIComponents
import ProtonCoreUIFoundations

protocol RatingBoosterOpeningCoordinator {
    func openRatingPopup()
}

@MainActor
protocol RatingBoosterCoordinatorProtocol: AnyObject, RatingBoosterOpeningCoordinator {
    func openNativeReview()
    func openHelp()
    func openBugReport()
    func close()
}

final class RatingBoosterCoordinator: RatingBoosterCoordinatorProtocol {
    private let bugReportFactory: BugReportFactoryProtocol
    private weak var presentedViewController: UIViewController?

    init(bugReportFactory: BugReportFactoryProtocol) {
        self.bugReportFactory = bugReportFactory
    }

    private func present(step: RatingBoosterPromptViewModel.Step) {
        guard let presenter = UIApplication.shared.topViewController() else {
            Log.warning("No view controller to present rating booster prompt", domain: .ui)
            return
        }
        
        let viewModel = RatingBoosterPromptViewModel(step: step, coordinator: self)
        let host = RatingBoosterPromptView(viewModel: viewModel).embeddedInTransparentHostingController()
        host.modalPresentationStyle = .overFullScreen
        presenter.present(host, animated: false)
        presentedViewController = host
    }

    private func dismiss(_ completion: (() -> Void)? = nil) {
        guard let presentedViewController else {
            completion?()
            return
        }
        self.presentedViewController = nil
        presentedViewController.dismiss(animated: false, completion: completion)
    }

    private func requestNativeReview() {
        guard let windowScene = UIApplication.shared.getActiveWindowScene() else {
            return
        }
        AppStore.requestReview(in: windowScene)
    }

    private func presentBugReport() {
        guard let topViewController = UIApplication.shared.topViewController() else {
            Log.warning("No view controller to present bug report", domain: .ui)
            return
        }
        let viewController = bugReportFactory.makeBugReportViewController()
        topViewController.present(viewController, animated: true)
    }

    func openRatingPopup() {
        Task { @MainActor in
            present(step: .enjoying)
        }
    }

    func openNativeReview() {
        dismiss { [weak self] in
            self?.requestNativeReview()
        }
    }

    func openHelp() {
        dismiss { [weak self] in
            self?.present(step: .help)
        }
    }

    func openBugReport() {
        dismiss { [weak self] in
            self?.presentBugReport()
        }
    }

    func close() {
        dismiss()
    }
}
