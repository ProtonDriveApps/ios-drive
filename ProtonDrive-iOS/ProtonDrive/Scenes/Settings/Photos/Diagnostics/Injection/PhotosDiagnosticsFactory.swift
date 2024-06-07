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
import PDCore
import SwiftUI

struct PhotosDiagnosticsFactory {
    func makeView(tower: Tower, settingsController: PhotoBackupSettingsController) -> AnyView {
        let dumpInteractor = TreeDumpInteractorFactory().make(sorter: { $0 < $1 }, obfuscator: { _ in })
        let interactor = PhotosDiagnosticsInteractor(
            libraryRepository: makeLibraryDumpRepository(settingsController: settingsController),
            databaseRepository: makeDatabaseDumpRepository(storageManager: tower.storage),
            cloudRepository: makeCloudDumpRepository(tower: tower),
            dumpInteractor: dumpInteractor,
            dumpStorageResource: ConcretePhotosDumpStorageResource(),
            diffStorageResource: ConcretePhotosDiffStorageResource(),
            differencesStrategy: ConcreteDiagnosticsTreeDifferencesStrategy(),
            changeToStringConvertor: makeChangeToStringConvertor()
        )

        let facade = ConcretePhotosDiagnosticsFacade(interactor: interactor)
        let diagnosticsViewModel = PhotosDiagnosticsViewModel(facade: facade)
        return PhotosDiagnosticsView(viewModel: diagnosticsViewModel).any()
    }

    private func makeLibraryDumpRepository(settingsController: PhotoBackupSettingsController) -> TreeRepository {
        return PhotosLibraryTreeRepository(
            optionsFactory: PHFetchOptionsFactory(supportedMediaTypes: settingsController.supportedMediaTypes, notOlderThan: settingsController.notOlderThan),
            nameResource: PHAssetNameResource(),
            filenameStrategy: LocalPhotoLibraryFilenameStrategy()
        )
    }

    private func makeDatabaseDumpRepository(storageManager: StorageManager) -> TreeRepository {
        return PhotosDatabaseTreeRepository(storageManager: storageManager, managedObjectContext: storageManager.newBackgroundContext())
    }

    private func makeCloudDumpRepository(tower: Tower) -> TreeRepository {
        return PhotosCloudTreeRepository(
            metadataRepository: PhotosDiagnosticsMetadataRepository(shareListing: tower.client, photosListing: tower.client),
            mappingInteractor: PhotosDiagnosticsMappingInteractor(decryptorFactory: ConcreteCloudDecryptorFactory(sessionVault: tower.sessionVault))
        )
    }
    
    private func makeChangeToStringConvertor() -> ChangeToStringConvertor {
        ChangeToStringConvertor {
            "index \($0.index ?? -1)\t\t id " + $0.title
        }
    }
}
