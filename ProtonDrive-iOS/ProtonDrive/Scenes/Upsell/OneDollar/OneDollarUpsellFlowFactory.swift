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
import PDUIComponents
import PDCore

struct OneDollarUpsellFlowController {
    var featureFlagEnabled: Bool
    var isPayedUser: Bool
    var isOnboarded: Bool
    var isUpsellShown: Bool
    
    func shouldPresentUpsellFlow() -> Bool {
        (Constants.isUITest || featureFlagEnabled)
        && isOnboarded
        && isPayedUser == false
        && isUpsellShown == false
    }
}
    
struct OneDollarUpsellFlowFactory {
    
    func makeIfNeeded(controller: OneDollarUpsellFlowController, settings: OneDollarUpsellSettings, container: SubscriptionsContainer) -> UIViewController? {
        controller.shouldPresentUpsellFlow() ? make(settings: settings, container: container) : nil
    }
    
    private func make(settings: OneDollarUpsellSettings, container: SubscriptionsContainer) -> UIViewController {
        let navigationController = UINavigationController()
        navigationController.navigationBar.isHidden = true
        
        let model = OneDollarUpsellViewModel(
            defaultPriceLabel: Constants.oneDollarPlanDefaultPrice,
            appStoreProductID: Constants.oneDollarPlanID,
            priceRepository: SubscriptionPriceRepository(),
            settings: settings,
            onButtonTapped: { [unowned navigationController] in
                self.present(subscriptionsViewController: container.makeRootViewController(), navigationController: navigationController)
            }, onSkipButtonTapped: { [unowned navigationController] in
                navigationController.dismiss(animated: true)
            }
        )
        
        let rootView = OneDollarUpsellView(model: model)
        navigationController.setViewControllers([UIHostingController(rootView: rootView)], animated: false)
        return navigationController
    }
    
    private func present(subscriptionsViewController: UIViewController, navigationController: UINavigationController) {
        navigationController.navigationBar.isHidden = false
        subscriptionsViewController.title = "Subscription"
        subscriptionsViewController.navigationItem.leftBarButtonItem = CloseBarButton { [unowned navigationController] in
            navigationController.dismiss(animated: true)
        }
        navigationController.setViewControllers([subscriptionsViewController], animated: true)
    }
    
}

#if DEBUG
struct OneDollarUpsellFlowTestsManager {
    
    private static let localSettings = LocalSettings(suite: Constants.appGroup)
    
    static func defaultUpsellInTestsIfNeeded() {
        guard DebugConstants.commandLineContains(flags: [.uiTests, .defaultUpsell]) else {
            return
        }
        localSettings.isUpsellShown = false
        DebugConstants.removeCommandLine(flags: [.defaultUpsell])
    }
    
    static func skipUpsellInTestsIfNeeded() {
        guard DebugConstants.commandLineContains(flags: [.uiTests, .clearAllPreference, .skipUpsell]) else {
            return
        }
        
        localSettings.isUpsellShown = true
    }
}
#endif
