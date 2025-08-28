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
import PDCoreIOS
import PDClient
import ProtonCoreAuthentication
import UIKit

struct ProtonFilePreviewFactory {
    func makeController(
        rootViewController: UIViewController?,
        container: ProtonFilePreviewContainer,
        tower: Tower
    ) -> ProtonFileOpeningControllerProtocol {
        let interactor = ProtonFileOpeningFactory().makeIdentifierInteractor(tower: tower)
        let urlFactory = ProtonFileOpeningFactory().makeURLFactory(tower: tower)
        let coordinator = ProtonFileCoordinator(container: container)
        coordinator.rootViewController = rootViewController
        let errorViewModel = ProtonFileErrorViewModel(messageHandler: UserMessageHandler())
        let controller = ProtonFileOpeningController(
            interactor: interactor,
            urlFactory: urlFactory,
            coordinator: coordinator,
            errorViewModel: errorViewModel
        )
        return controller
    }

    func makePreviewViewController(
        identifier: ProtonFileIdentifier,
        coordinator: ProtonFileCoordinatorProtocol,
        tower: Tower,
        authenticator: Authenticator,
        openingController: ProtonFileOpeningControllerProtocol
    ) -> UIViewController {
        let nodeIdentifier = NodeIdentifier(identifier.linkId, identifier.shareId, identifier.volumeId)
        let urlInteractor = ProtonFileOpeningFactory().makeAuthenticatedURLInteractor(tower: tower, authenticator: authenticator)
        let nodeObserverController = tower.storage.subscriptionToNode(nodeIdentifier: nodeIdentifier, moc: tower.storage.backgroundContext)
        let observer = FetchedResultsControllerObserver(controller: nodeObserverController, isAutomaticallyStarted: false)
        let nameDataSource = DatabaseProtonDocsDecryptedNameDataSource(observer: observer)
        let viewModel = ProtonFileWebViewModel(
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
        return ProtonFileWebViewController(viewModel: viewModel, cookieStorage: cookieStorage, actionsMenu: actionsMenu)
    }

    private func makeActionsMenu(
        identifier: ProtonFileIdentifier,
        coordinator: ProtonFileCoordinatorProtocol,
        openingController: ProtonFileOpeningControllerProtocol
    ) -> UIMenu {
        let viewModel = ProtonFileActionsViewModel(identifier: identifier, coordinator: coordinator, openingController: openingController)
        return ProtonFileActionsMenu(viewModel: viewModel)
    }

    func makeRenameViewController(identifier: ProtonFileIdentifier, tower: Tower) -> UIViewController? {
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
