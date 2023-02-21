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
import PDClient
import ProtonCore_APIClient

final class FileUploadOperationsFactory {
    private let storage: StorageManager
    private let cloudSlot: CloudSlot
    private let sessionVault: SessionVault
    private let apiService: APIService

    init(
        storage: StorageManager,
        cloudSlot: CloudSlot,
        sessionVault: SessionVault,
        apiService: APIService
    ) {
        self.storage = storage
        self.cloudSlot = cloudSlot
        self.sessionVault = sessionVault
        self.apiService = apiService
    }

    func makeFileUploadOperationsProvider() -> FileUploadOperationsProvider {
        #if os(macOS)
        return defaultFileUploadOperationsProvider()
        #else
        if Constants.runningInExtension {
            return fileProviderFileUploadOperationsProvider()
        } else {
            return defaultFileUploadOperationsProvider()
        }
        #endif
    }

    func defaultFileUploadOperationsProvider() -> FileUploadOperationsProvider {
        let fileDraftUploader = DefaultFileDraftUploaderOperationFactory(cloudSlot: cloudSlot, sessionVault: sessionVault, storage: storage)
        let revisionCreator = DefaultRevisionCreatorOperationFactory(revisionCreator: cloudSlot, finalizer: cloudSlot.storage)
        let encryptRevision = DiscreteEncryptionRevisionOperationFactory(storage: storage, signersKitFactory: sessionVault)
        let revisionUploader = DiscreteRevisionUploaderOperationFactory(api: apiService, contentCreator: cloudSlot, credentialProvider: sessionVault)
        let revisionSealer = DefaultRevisionSealerOperationFactory(cloudRevisionSealer: cloudSlot, failedMarker: storage)

        return DefaultFileUploadOperationsProvider(
            fileDraftUploaderOperationFactory: fileDraftUploader,
            revisionCreatorOperationFactory: revisionCreator,
            revisionEncryptorOperationFactory: encryptRevision,
            revisionUploaderOperationFactory: revisionUploader,
            revisionSealerOperationFactory: revisionSealer,
            completedStepsFileUploadOperationFactory: DefaultCompletedStepsFileUploadOperationFactory(),
            mainFileUploaderOperationFactory: DefaultMainFileUploaderOperationFactory()
        )
    }

    func fileProviderFileUploadOperationsProvider() -> FileUploadOperationsProvider {
        let fileDraftUploader = DefaultFileDraftUploaderOperationFactory(cloudSlot: cloudSlot, sessionVault: sessionVault, storage: storage)
        let revisionCreator = DefaultRevisionCreatorOperationFactory(revisionCreator: cloudSlot, finalizer: cloudSlot.storage)
        let encryptRevision = StreamEncryptionRevisionOperationFactory(storage: storage, signersKitFactory: sessionVault)
        let revisionUploader = StreamRevisionUploaderOperationFactory(api: apiService, contentCreator: cloudSlot, credentialProvider: sessionVault)
        let revisionSealer = DefaultRevisionSealerOperationFactory(cloudRevisionSealer: cloudSlot, failedMarker: storage)

        return DefaultFileUploadOperationsProvider(
            fileDraftUploaderOperationFactory: fileDraftUploader,
            revisionCreatorOperationFactory: revisionCreator,
            revisionEncryptorOperationFactory: encryptRevision,
            revisionUploaderOperationFactory: revisionUploader,
            revisionSealerOperationFactory: revisionSealer,
            completedStepsFileUploadOperationFactory: DefaultCompletedStepsFileUploadOperationFactory(),
            mainFileUploaderOperationFactory: DefaultMainFileUploaderOperationFactory()
        )
    }
}
