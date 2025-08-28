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
import Photos
import PDUIComponents

protocol NativeSharePhotoCoordinatorProtocol {
    func set(rootViewController: UIViewController?)
    func openNativeShare(url: URL, completion: @escaping () -> Void)
    func openNativeShareForLivePhoto(imageURL: URL, videoURL: URL, completion: @escaping () -> Void)
    func openNativeShareForBurstPhoto(urls: [URL], completion: @escaping () -> Void)
}

final class NativeSharePhotoCoordinator: NativeSharePhotoCoordinatorProtocol {
    private weak var activityVC: UIActivityViewController?
    private weak var rootViewController: UIViewController?

    init(rootViewController: UIViewController?) {
        self.rootViewController = rootViewController
    }

    func set(rootViewController: UIViewController?) {
        self.rootViewController = rootViewController
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

    func openNativeShareForBurstPhoto(urls: [URL], completion: @escaping () -> Void) {
        var activities: [UIActivity] = []
        if PHPhotoLibrary.authorizationStatus(for: .addOnly) != .denied {
            activities.append(SaveBurstPhotoActivity(urls: urls))
        }
        openShareActivity(
            items: urls,
            activities: activities,
            excludeActivities: [.saveToCameraRoll],
            completion: completion
        )
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

    private func rectForShareActivity() -> CGRect {
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
}
