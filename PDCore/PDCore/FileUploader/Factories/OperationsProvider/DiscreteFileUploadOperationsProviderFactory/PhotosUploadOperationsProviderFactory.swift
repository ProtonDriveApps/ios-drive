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
import CoreData

public final class PhotosUploadOperationsProviderFactory: FileUploadOperationsProviderFactory {

    private let storage: StorageManager
    private let client: PDClient.Client
    private let cloudSlot: CloudSlotProtocol
    private let sessionVault: SessionVault
    private let apiService: APIService
    private let moc: NSManagedObjectContext
    private let parallelEncryption: Bool
    private let pagesQueue: OperationQueue
    private let uploadQueue: OperationQueue
    private let encryptionQueue: OperationQueue
    private let verifierFactory: UploadVerifierFactory
    private let finishResource: PhotoUploadFinishResource
    private let blocksMeasurementRepository: FileUploadBlocksMeasurementRepositoryProtocol
    private let uploadedBytesCounterResource: BytesCounterResource

    public init(
        storage: StorageManager,
        client: PDClient.Client,
        cloudSlot: CloudSlotProtocol,
        sessionVault: SessionVault,
        apiService: APIService,
        moc: NSManagedObjectContext,
        parallelEncryption: Bool,
        pagesQueue: OperationQueue,
        uploadQueue: OperationQueue,
        encryptionQueue: OperationQueue,
        verifierFactory: UploadVerifierFactory,
        finishResource: PhotoUploadFinishResource,
        blocksMeasurementRepository: FileUploadBlocksMeasurementRepositoryProtocol,
        uploadedBytesCounterResource: BytesCounterResource
    ) {
        self.storage = storage
        self.client = client
        self.cloudSlot = cloudSlot
        self.sessionVault = sessionVault
        self.apiService = apiService
        self.moc = moc
        self.parallelEncryption = parallelEncryption
        self.pagesQueue = pagesQueue
        self.uploadQueue = uploadQueue
        self.encryptionQueue = encryptionQueue
        self.verifierFactory = verifierFactory
        self.finishResource = finishResource
        self.blocksMeasurementRepository = blocksMeasurementRepository
        self.uploadedBytesCounterResource = uploadedBytesCounterResource
    }

    public func make() -> FileUploadOperationsProvider {
        let revisionEncryptor = PhotosRevisionEncryptorOperationFactory(signersKitFactory: sessionVault, moc: moc, globalQueue: encryptionQueue, parallelEncryption: parallelEncryption)
        let fileDraftCreator = PhotoDraftCreatorOperationFactory(fileDraftCreator: cloudSlot, sessionVault: sessionVault)
        let revisionDraftCreator = PhotoRevisionDraftCreatorOperationFactory()
        let revisionUploader = DiscreteRevisionUploaderOperationFactory(storage: storage, client: client, api: apiService, cloudContentCreator: cloudSlot, credentialProvider: sessionVault, signersKitFactory: sessionVault, verifierFactory: verifierFactory, moc: moc, parallelEncryption: parallelEncryption, globalPagesQueue: pagesQueue, globalUploadQueue: uploadQueue, blocksMeasurementRepository: blocksMeasurementRepository, uploadedBytesCounterResource: uploadedBytesCounterResource)
        let revisionCommitter = PhotoRevisionCommitterOperationFactory(cloudRevisionCommitter: cloudSlot, uploadedRevisionChecker: cloudSlot, signersKitFactory: sessionVault, moc: moc, finishResource: finishResource)

        let operationsProvider = PhotosUploadOperationsProvider(
            revisionEncryptorOperationFactory: revisionEncryptor,
            fileDraftCreatorOperationFactory: fileDraftCreator,
            revisionCreatorOperationFactory: revisionDraftCreator,
            revisionUploaderOperationFactory: revisionUploader,
            revisionCommitterOperationFactory: revisionCommitter
        )
        return operationsProvider
    }

}
