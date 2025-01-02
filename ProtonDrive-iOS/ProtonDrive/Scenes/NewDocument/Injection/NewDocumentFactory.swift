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
import UIKit

struct NewDocumentFactory {
    func makeView(tower: Tower, previewContainer: ProtonDocumentPreviewContainer) -> NewDocumentLoadingView {
        let interactor = makeInteractor(tower: tower)
        let facade = NewDocumentFacade(interactor: interactor)
        // Needs UIApplication.shared top viewController since it's invoked from SwiftUI
        let openingController = previewContainer.makeController(rootViewController: UIApplication.shared.topViewController())
        let viewModel = NewDocumentViewModel(
            facade: facade,
            openingController: openingController,
            messageHandler: UserMessageHandler(),
            dateResource: PlatformCurrentDateResource(),
            dateFormatter: PlatformDateFormatterResource()
        )
        return NewDocumentLoadingView(viewModel: viewModel)
    }

    private func makeInteractor(tower: Tower) -> NewDocumentInteractor {
        let payloadFactory = NewDocumentPayloadFactory(
            signersKitFactory: tower.sessionVault,
            managedObjectContext: tower.storage.backgroundContext,
            storageManager: tower.storage,
            encryptionResource: Encryptor()
        )
        let updateRepository = CoreDataLinksUpdateRepository(
            cloudSlot: tower.cloudSlot,
            managedObjectContext: tower.storage.backgroundContext
        )
        return NewDocumentInteractor(
            payloadFactory: payloadFactory,
            createDocumentRepository: tower.client,
            metadataRepository: tower.client,
            updateRepository: updateRepository
        )
    }
}
