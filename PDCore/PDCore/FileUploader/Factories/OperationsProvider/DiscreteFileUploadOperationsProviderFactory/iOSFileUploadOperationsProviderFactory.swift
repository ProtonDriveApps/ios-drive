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

final class iOSFileUploadOperationsProviderFactory: DiscreteFileUploadOperationsProviderFactory {

    override func make() -> FileUploadOperationsProvider {
        let revisionEncryptor = DiscreteRevisionEncryptorOperationFactory(signersKitFactory: sessionVault, moc: moc)
        let fileDraftCreator = NameResolvingFileDraftCreatorOperationFactory(hashChecker: cloudSlot, fileDraftCreator: cloudSlot, sessionVault: sessionVault, moc: moc)
        let revisionDraftCreator = RevisionDraftCreatorOperationFactory(cloudRevisionCreator: cloudSlot, moc: moc)
        let revisionUploader = DiscreteRevisionUploaderOperationFactory(storage: storage, client: client, api: apiService, cloudContentCreator: cloudSlot, credentialProvider: sessionVault, signersKitFactory: sessionVault, verifierFactory: verifierFactory, moc: moc)
        let revisionCommitter = RevisionCommitterOperationFactory(cloudRevisionCommitter: cloudSlot, uploadedRevisionChecker: cloudSlot, signersKitFactory: sessionVault, moc: moc)

        return MyFilesFileUploadOperationsProvider(
            revisionEncryptorOperationFactory: revisionEncryptor,
            fileDraftCreatorOperationFactory: fileDraftCreator,
            revisionCreatorOperationFactory: revisionDraftCreator,
            revisionUploaderOperationFactory: revisionUploader,
            revisionCommitterOperationFactory: revisionCommitter
        )
    }

}
