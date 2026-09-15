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
import PDUIComponents

@MainActor
protocol UpsellCoordinatorProtocol: AnyObject {
    func showCustomUpsell(_ offer: UpsellOfferData)
    func showSubscriptions()
    func open(url: URL)
    func dismiss()
}

/// Upsell container that can be invoked from any button in the app
/// - either tries to open custom modal (if FF and payload is available)
/// - or falls back to default subscription screen, owned by Account team
public final class UpsellCoordinator: UpsellCoordinatorProtocol {
    private let container: UpsellContainer
    private let subscriptionsContainer: SubscriptionsContainer
    private weak var rootViewController: UpsellRootViewController?

    public init(
        container: UpsellContainer,
        subscriptionsContainer: SubscriptionsContainer
    ) {
        self.container = container
        self.subscriptionsContainer = subscriptionsContainer
    }

    public func present(from viewController: UIViewController?) {
        guard let viewController else { return }
        // The view model owns (retains) us and invokes us once its async load resolves; the
        // view model is in turn owned by the view controller, which UIKit retains while it is
        // presented. We hold the view controller only weakly, avoiding a retain cycle.
        let rootViewController = container.makeRootViewController(coordinator: self)
        self.rootViewController = rootViewController
        viewController.present(rootViewController, animated: true)
    }

    /// Custom modal: embed the SwiftUI upsell view as a child of the plain root.
    func showCustomUpsell(_ offer: UpsellOfferData) {
        guard let rootViewController else {
            return
        }
        let modalViewController = container.makeModalViewController(offer: offer, coordinator: self)
        rootViewController.add(modalViewController)
    }

    /// Fallback: the legacy subscriptions screen needs to live inside a navigation
    /// controller, so we embed a `UINavigationController` as a child of the plain root.
    func showSubscriptions() {
        guard let rootViewController else {
            return
        }
        let subscriptionsViewController = subscriptionsContainer.makeRootViewController()
        let navigationViewController = ModalNavigationViewController(rootViewController: subscriptionsViewController)
        rootViewController.add(navigationViewController)
    }

    func open(url: URL) {
        guard UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    func dismiss() {
        rootViewController?.dismiss(animated: true)
    }
}
