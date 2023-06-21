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

public final class PhotosUploadOperationsProviderFactory: FileUploadOperationsProviderFactory {

    private let storage: StorageManager
    private let cloudSlot: CloudSlot
    private let sessionVault: SessionVault
    private let apiService: APIService

    public init(
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

    public func make() -> FileUploadOperationsProvider {
        let revisionEncryptor = PhotosRevisionEncryptorOperationFactory(signersKitFactory: sessionVault, moc: storage.backgroundContext)
        let fileDraftCreator = PhotoDraftCreatorOperationFactory(hashChecker: cloudSlot, fileDraftCreator: cloudSlot, sessionVault: sessionVault, storage: storage)
        let revisionDraftCreator = PhotoRevisionDraftCreatorOperationFactory()
        let revisionUploader = DiscreteRevisionUploaderOperationFactory(api: apiService, moc: storage.backgroundContext, cloudContentCreator: cloudSlot, credentialProvider: sessionVault, signersKitFactory: sessionVault)
        let revisionCommitter = PhotoRevisionCommitterOperationFactory(cloudRevisionCommitter: cloudSlot, signersKitFactory: sessionVault, moc: storage.backgroundContext)

        return DefaultFileUploadOperationsProvider(
            revisionEncryptorOperationFactory: revisionEncryptor,
            fileDraftUploaderOperationFactory: fileDraftCreator,
            revisionCreatorOperationFactory: revisionDraftCreator,
            revisionUploaderOperationFactory: revisionUploader,
            revisionSealerOperationFactory: revisionCommitter
        )
    }

}
