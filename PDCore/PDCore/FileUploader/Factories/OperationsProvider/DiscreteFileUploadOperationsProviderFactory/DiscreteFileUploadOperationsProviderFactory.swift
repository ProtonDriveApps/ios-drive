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
import CoreData

public class DiscreteFileUploadOperationsProviderFactory: FileUploadOperationsProviderFactory {

    let storage: StorageManager
    let cloudSlot: CloudSlot
    let sessionVault: SessionVault
    let apiService: APIService
    
    var moc: NSManagedObjectContext {
        storage.backgroundContext
    }

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
        let revisionEncryptor = DiscreteRevisionEncryptorOperationFactory(signersKitFactory: sessionVault, moc: moc)
        let fileDraftCreator = DefaultFileDraftCreatorOperationFactory(fileDraftCreator: cloudSlot, sessionVault: sessionVault)
        let revisionDraftCreator = RevisionDraftCreatorOperationFactory(cloudRevisionCreator: cloudSlot, moc: moc)
        let revisionUploader = DiscreteRevisionUploaderOperationFactory(api: apiService, cloudContentCreator: cloudSlot, credentialProvider: sessionVault, signersKitFactory: sessionVault, moc: moc)
        let revisionCommitter = RevisionCommitterOperationFactory(cloudRevisionCommitter: cloudSlot, signersKitFactory: sessionVault, moc: moc)

        return DefaultFileUploadOperationsProvider(
            revisionEncryptorOperationFactory: revisionEncryptor,
            fileDraftCreatorOperationFactory: fileDraftCreator,
            revisionCreatorOperationFactory: revisionDraftCreator,
            revisionUploaderOperationFactory: revisionUploader,
            revisionSealerOperationFactory: revisionCommitter
        )
    }

}
