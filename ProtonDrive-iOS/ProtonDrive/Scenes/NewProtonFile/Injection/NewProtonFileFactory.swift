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
import UIKit

struct NewProtonFileFactory {
    func makeView(tower: Tower, previewContainer: ProtonFilePreviewContainer, fileType: ProtonFileType) -> NewProtonFileLoadingView {
        let interactor = makeInteractor(tower: tower, fileType: fileType)
        let facade = NewProtonFileFacade(interactor: interactor)
        // Needs UIApplication.shared top viewController since it's invoked from SwiftUI
        let openingController = previewContainer.makeController(rootViewController: UIApplication.shared.topViewController())
        let viewModel = NewProtonFileViewModel(
            facade: facade,
            openingController: openingController,
            messageHandler: UserMessageHandler(),
            dateResource: PlatformCurrentDateResource(),
            dateFormatter: PlatformDateFormatterResource(),
            fileType: fileType
        )
        return NewProtonFileLoadingView(viewModel: viewModel)
    }

    private func makeInteractor(tower: Tower, fileType: ProtonFileType) -> NewProtonFileInteractor {
        let payloadFactory = NewProtonFilePayloadFactory(
            signersKitFactory: tower.sessionVault,
            managedObjectContext: tower.storage.backgroundContext,
            storageManager: tower.storage,
            encryptionResource: Encryptor(),
            fileType: fileType
        )
        let updateRepository = CoreDataLinksUpdateRepository(
            cloudSlot: tower.cloudSlot,
            managedObjectContext: tower.storage.backgroundContext
        )
        return NewProtonFileInteractor(
            payloadFactory: payloadFactory,
            createDocumentRepository: tower.client,
            metadataRepository: tower.client,
            updateRepository: updateRepository
        )
    }
}
