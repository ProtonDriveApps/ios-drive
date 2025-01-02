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

import PDCore
import PDClient
import ProtonCoreAuthentication
import UIKit

struct ProtonDocumentPreviewFactory {
    func makeController(
        rootViewController: UIViewController?,
        container: ProtonDocumentPreviewContainer,
        tower: Tower,
        featureFlagsController: FeatureFlagsControllerProtocol
    ) -> ProtonDocumentOpeningControllerProtocol {
        let interactor = ProtonDocumentOpeningFactory().makeIdentifierInteractor(tower: tower)
        let urlFactory = ProtonDocumentOpeningFactory().makeURLFactory(tower: tower)
        let coordinator = ProtonDocumentCoordinator(container: container)
        coordinator.rootViewController = rootViewController
        let errorViewModel = ProtonDocumentErrorViewModel(messageHandler: UserMessageHandler())
        let controller = ProtonDocumentOpeningController(
            interactor: interactor,
            urlFactory: urlFactory,
            coordinator: coordinator,
            errorViewModel: errorViewModel,
            featureFlagsController: featureFlagsController
        )
        return controller
    }

    func makePreviewViewController(
        identifier: ProtonDocumentIdentifier,
        coordinator: ProtonDocumentCoordinatorProtocol,
        tower: Tower,
        authenticator: Authenticator,
        openingController: ProtonDocumentOpeningControllerProtocol
    ) -> UIViewController {
        let nodeIdentifier = NodeIdentifier(identifier.linkId, identifier.shareId, identifier.volumeId)
        let urlInteractor = ProtonDocumentOpeningFactory().makeAuthenticatedURLInteractor(tower: tower, authenticator: authenticator)
        let nodeObserverController = tower.storage.subscriptionToNode(nodeIdentifier: nodeIdentifier, moc: tower.storage.backgroundContext)
        let observer = FetchedResultsControllerObserver(controller: nodeObserverController, isAutomaticallyStarted: false)
        let nameDataSource = DatabaseProtonDocsDecryptedNameDataSource(observer: observer)
        let viewModel = ProtonDocumentWebViewModel(
            identifier: identifier,
            configuration: tower.api.configuration,
            coordinator: coordinator,
            storageResource: LocalFileStorageResource(),
            messageHandler: UserMessageHandler(),
            urlInteractor: urlInteractor,
            nameDataSource: nameDataSource
        )
        let cookieStorage = tower.networking.getSession()?.sessionConfiguration.httpCookieStorage ?? HTTPCookieStorage.shared
        let actionsMenu = makeActionsMenu(identifier: identifier, coordinator: coordinator, openingController: openingController)
        return ProtonDocumentWebViewController(viewModel: viewModel, cookieStorage: cookieStorage, actionsMenu: actionsMenu)
    }

    private func makeActionsMenu(
        identifier: ProtonDocumentIdentifier,
        coordinator: ProtonDocumentCoordinatorProtocol,
        openingController: ProtonDocumentOpeningControllerProtocol
    ) -> UIMenu {
        let viewModel = ProtonDocumentActionsViewModel(identifier: identifier, coordinator: coordinator, openingController: openingController)
        return ProtonDocumentActionsMenu(viewModel: viewModel)
    }

    func makeRenameViewController(identifier: ProtonDocumentIdentifier, tower: Tower) -> UIViewController? {
        let nodeIdentifier = NodeIdentifier(identifier.linkId, identifier.shareId, identifier.volumeId)

        // FIXME: Current solution expects passing of `Node` object. Refactor in the future.
        guard let node = tower.storage.fetchNode(id: nodeIdentifier, moc: tower.storage.mainContext) else {
            return nil
        }

        let editedNode = NameEditingNode(node: node)
        let nodeRenamer = NodeRenamer(
            storage: tower.storage,
            cloudNodeRenamer: tower.client.renameEntry,
            signersKitFactory: tower.sessionVault,
            moc: tower.storage.backgroundContext
        )
        let nameEditor = NodeNameEditor(
            storage: tower.storage,
            managedObjectContext: tower.storage.backgroundContext,
            nodeRenamer: nodeRenamer
        )
        let viewModel = EditNodeNameViewModel(node: editedNode, nameEditor: nameEditor, validator: NameValidations.userSelectedName)
        let formattingViewModel = FormattingFileViewModel(
            initialName: editedNode.fullName,
            nameAttributes: EditNodeViewController.nameAttributes,
            extensionAttributes: EditNodeViewController.nameAttributes
        )
        let viewController = EditNodeViewController()
        viewController.viewModel = viewModel
        viewController.tfViewModel = formattingViewModel
        return viewController
    }
}
