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

import UIKit
import Photos

final class PhotosPreviewCoordinator: PhotosPreviewListCoordinator, PhotosPreviewDetailFactory, PhotoPreviewDetailCoordinator {
    let container: PhotosPreviewContainer
    weak var rootViewController: UIViewController?
    private weak var activityVC: UIActivityViewController?

    init(container: PhotosPreviewContainer) {
        self.container = container
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    // MARK: - PhotosPreviewListCoordinator

    func close() {
        rootViewController?.dismiss(animated: true)
    }

    // MARK: - PhotosPreviewDetailFactory

    func makeViewController(with id: PhotoId) -> UIViewController {
        container.makeDetailViewController(with: id)
    }

    // MARK: - PhotoPreviewDetailCoordinator

    func openShare(url: URL) {
        openShareActivity(items: [url])
    }
    
    func openShareLivePhoto(imageURL: URL, videoURL: URL) {
        Task {
            let livePhoto = await PHLivePhoto.load(resources: [imageURL, videoURL])
            await MainActor.run {
                if livePhoto == nil {
                    openShare(url: imageURL)
                } else {
                    var activities: [UIActivity] = []
                    if PHPhotoLibrary.authorizationStatus(for: .addOnly) != .denied {
                        activities.append(SaveLivePhotoActivity(imageURL: imageURL, videoURL: videoURL))
                        
                    }
                    openShareActivity(
                        items: [imageURL],
                        activities: activities,
                        excludedActivities: [.saveToCameraRoll]
                    )
                }
            }
        }
    }
    
    private func openShareActivity(
        items: [Any],
        activities: [UIActivity]? = nil,
        excludedActivities: [UIActivity.ActivityType]? = nil
    ) {
        guard
            let rootViewController = rootViewController,
            let view = rootViewController.view,
            let item = sourceItemForActivity()
        else { return }

        let viewController = UIActivityViewController(activityItems: items, applicationActivities: activities)
        viewController.excludedActivityTypes = excludedActivities
        if #available(iOS 16.0, *) {
            viewController.popoverPresentationController?.sourceItem = item
        } else {
            viewController.popoverPresentationController?.barButtonItem = item
        }
        viewController.popoverPresentationController?.sourceView = view
        activityVC = viewController
        rootViewController.present(viewController, animated: true, completion: nil)
    }
    
    @objc
    private func orientationDidChange() {
        // Add a small delay to waiting for navigation item setup
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
            guard
                let popover = self.activityVC?.popoverPresentationController,
                let item = self.sourceItemForActivity()
            else { return }
            if #available(iOS 16.0, *) {
                popover.sourceItem = item
            } else {
                popover.barButtonItem = item
            }
        }
    }
    
    private func sourceItemForActivity() -> UIBarButtonItem? {
        guard let scene = rootViewController?.view.window?.windowScene else { return nil }
        if scene.interfaceOrientation.isPortrait {
            return rootViewController?.toolbarItems?.first
        } else {
            return rootViewController?.navigationItem.rightBarButtonItem
        }
    }
}
