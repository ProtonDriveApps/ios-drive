// Copyright (c) 2026 Proton AG
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
import PDCore
import PDSDKCore
import PDUIComponents
import SwiftUI
import UIKit

@MainActor
final class IIncomingFilesCoordinator {
    private weak var reviewHostingController: UIViewController?
    private var pickerCoordinator: FFinderCoordinator?

    func present(
        on rootViewController: UIViewController,
        with authenticatedContainer: AuthenticatedDependencyContainer
    ) {
        Log.info("Presenting incoming files save view", domain: .shareExtension)
        Task { @MainActor in
            guard let rootNode = await Self.fetchMyFilesRoot(tower: authenticatedContainer.tower) else {
                Log.error("Incoming files root folder is unavailable", error: nil, domain: .shareExtension)
                return
            }

            let viewModel = IIncomingFilesReviewViewModel(
                rootNode: rootNode,
                authenticatedContainer: authenticatedContainer
            )
            // SceneDelegate does not retain the coordinator, so capture `self`
            // strongly here. The hosting controller transitively owns these
            // closures; when it is dismissed the closures (and `self`) are
            // released, so no cycle is introduced.
            viewModel.onPickDestination = { onSaveHere in
                self.presentDestinationPicker(
                    authenticatedContainer: authenticatedContainer,
                    onSaveHere: onSaveHere
                )
            }

            let reviewView = IIncomingFilesReviewView(
                viewModel: viewModel,
                onCancel: {
                    self.reviewHostingController?.dismiss(animated: true)
                },
                onUploadFinished: {
                    self.reviewHostingController?.dismiss(animated: true)
                }
            )
            let rootView = RootView(vm: RootViewModel(), activeArea: { reviewView })
            let vc = UIHostingController(rootView: rootView)
            vc.isModalInPresentation = true
            self.reviewHostingController = vc
            rootViewController.present(vc, animated: true)
        }
    }

    private func presentDestinationPicker(
        authenticatedContainer: AuthenticatedDependencyContainer,
        onSaveHere: @escaping (NodeDTO) -> Void
    ) {
        guard let reviewHostingController else { return }

        let coordinator = FFinderCoordinator(
            dependencies: .init(
                container: authenticatedContainer,
                scrollToTopPublisher: nil
            )
        )
        self.pickerCoordinator = coordinator

        // FFinderViewModel.Dependencies retains this coordinator, and the
        // coordinator strongly retains its navigation stack; that creates a
        // cycle. Break it once the modal animation finishes (covers both
        // Save Here and Cancel paths) so all picker view models, scenes, and
        // children sources are released.
        coordinator.onDismissed = { [weak self, weak coordinator] in
            coordinator?.tearDown()
            self?.pickerCoordinator = nil
        }

        let pickerRoot = coordinator.start(location: .incomingFilesPickerRoot(onSaveHere: onSaveHere))
        pickerRoot.isModalInPresentation = true
        reviewHostingController.present(pickerRoot, animated: true)
    }

    private static func fetchMyFilesRoot(tower: Tower) async -> NodeDTO? {
        let fetcher = MyFilesRootFetcher(storage: tower.storage)
        let nodeIdentifier = fetcher.getRoot()
        return try? await tower.storage.backgroundContextPool.performInContext { context in
            guard let folder = CoreDataFolder.fetch(identifier: nodeIdentifier, in: context) else {
                throw CoreDataFolder.InvalidState(message: "failed to get incoming files root folder")
            }
            return try? NodeDTO(node: folder, signatureKeys: [])
        }
    }
}
