// Copyright (c) 2023 Proton AG
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
import ProtonCoreFoundations
import UIKit
import PDUIComponents
import SwiftUI
import Photos

final class PhotosCoordinator: PhotosRootCoordinator, PhotosPermissionsCoordinator, PhotoItemCoordinator, PhotosActionCoordinator, PhotosStorageCoordinator, PhotosStateCoordinator {
    private let container: PhotosScenesContainer
    weak var rootViewController: UIViewController?
    private weak var activityVC: UIActivityViewController?

    private var navigationViewController: UINavigationController? {
        rootViewController?.navigationController
    }

    init(container: PhotosScenesContainer) {
        self.container = container
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    func openMenu() {
        NotificationCenter.default.post(.toggleSideMenu)
    }

    func close() {
        rootViewController?.dismiss(animated: true)
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.openURLIfPossible(url)
        }
    }

    func openPreview(with id: PhotoId) {
        let viewController = container.makePreviewController(id: id)
        viewController.modalPresentationStyle = .fullScreen
        navigationViewController?.present(viewController, animated: true)
    }

    func updateTabBar(isHidden: Bool) {
        let userInfo: [String: Bool] = ["tabBarHidden": isHidden]
        NotificationCenter.default.post(name: FinderNotifications.tabBar.name, object: nil, userInfo: userInfo)
    }

    func openShare(id: PhotoId) {
        guard let viewController = container.makeShareViewController(id: id) else {
            return
        }
        navigationViewController?.present(viewController, animated: true)
    }

    func openNativeShare(url: URL, completion: @escaping () -> Void) {
        openShareActivity(items: [url], completion: completion)
    }
    
    func openNativeShareForLivePhoto(imageURL: URL, videoURL: URL, completion: @escaping () -> Void) {
        Task {
            let livePhoto = await PHLivePhoto.load(resources: [imageURL, videoURL])
            await MainActor.run {
                if livePhoto == nil {
                    openShareActivity(items: [imageURL], activities: [], completion: completion)
                } else {
                    var activities: [UIActivity] = []
                    if PHPhotoLibrary.authorizationStatus(for: .addOnly) != .denied {
                        activities.append(SaveLivePhotoActivity(imageURL: imageURL, videoURL: videoURL))
                        
                    }
                    openShareActivity(
                        items: [imageURL],
                        activities: activities,
                        excludeActivities: [.saveToCameraRoll],
                        completion: completion
                    )
                }
            }
        }
    }
    
    private func openShareActivity(
        items: [Any],
        activities: [UIActivity]? = nil,
        excludeActivities: [UIActivity.ActivityType]? = nil,
        completion: @escaping () -> Void
    ) {
        guard
            let rootViewController = rootViewController,
            let sourceView = rootViewController.view
        else { return }
        
        let viewController = UIActivityViewController(activityItems: items, applicationActivities: activities)
        viewController.excludedActivityTypes = excludeActivities
        if let popover = viewController.popoverPresentationController {
            popover.sourceView = sourceView
            // When sheet has permittedArrow, `sourceRect` is the rectangle that the popover’s arrow points to
            // But if there is no arrow, `sourceRect` is the center of sheet
            popover.sourceRect = rectForShareActivity()
            // Remove sheet arrow in the bottom
            popover.permittedArrowDirections = []
        }
        viewController.completionWithItemsHandler = { _, _, _, _ in
            completion()
        }
        activityVC = viewController
        rootViewController.present(viewController, animated: true, completion: nil)
    }
    
    func rectForShareActivity() -> CGRect {
        guard
            let view = rootViewController?.view,
            let window = view.window,
            let screenSize = view.realScreenSize()
        else { return .zero }

        let safeBottom = window.safeAreaInsets.bottom
        let sheetHeight: CGFloat = 573
        let padding: CGFloat = 8
        let screenHeight = screenSize.height
        let screenWidth = screenSize.width
        let y = screenHeight - safeBottom - ActionBarSize.height - padding - sheetHeight / 2
        return CGRect(x: screenWidth / 2, y: y, width: 0, height: 0)
    }

    func openSubscriptions() {
        let viewController = container.makeSubscriptionsViewController()
        let navigationViewController = ModalNavigationViewController(rootViewController: viewController)
        navigationViewController.modalPresentationStyle = .fullScreen
        rootViewController?.present(navigationViewController, animated: true)
    }
    
    func openRetryScreen() {
        let viewController = container.makeRetryViewController()
        rootViewController?.present(viewController, animated: true)
    }
    
    func openSystemSettingPage() {
        guard 
            let settingsUrl = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(settingsUrl) 
        else { return }
        UIApplication.shared.open(settingsUrl) { _ in }
    }
    
    func openUpsellView() {
        let viewModel = PhotoUpsellViewModel()
        let view = PhotoUpsellView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        rootViewController?.present(viewController, animated: true)
    }
    
    @objc
    private func orientationDidChange() {
        guard let popover = activityVC?.popoverPresentationController else { return }
        // ActionBar size is changed, needs to update share sheet frame
        popover.sourceRect = rectForShareActivity()
    }
}
