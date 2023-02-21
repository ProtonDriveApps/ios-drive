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

protocol FileDraftUploaderOperationFactory {

    func make(from draft: FileDraft, onError: @escaping OnError) -> OperationWithProgress
}

final class DefaultFileDraftUploaderOperationFactory: FileDraftUploaderOperationFactory {

    private let cloudSlot: CloudSlot
    private let sessionVault: SessionVault
    private let storage: StorageManager

    init(
        cloudSlot: CloudSlot,
        sessionVault: SessionVault,
        storage: StorageManager
    ) {
        self.cloudSlot = cloudSlot
        self.sessionVault = sessionVault
        self.storage = storage
    }

    func make(from draft: FileDraft, onError: @escaping OnError) -> OperationWithProgress {
        FileDraftUploaderOperation(
            unitOfWork: 100,
            draft: draft,
            fileDraftUploader: fileDraftUploader(draft),
            onError: onError
        )
    }

    func fileDraftUploader(_ draft: FileDraft) -> FileDraftUploader {
        let nameDiscoverer = makeNameDiscoverer()
        let attributesCreator = makeAttributesCreator(draft)
        let finalizer = makeFileDraftUploaderFinalizer(draft, attributesCreator)

        return NameClashResolvingFileDraftUploader(
            cloudFileCreator: cloudSlot,
            validNameDiscoverer: nameDiscoverer,
            signersKitFactory: sessionVault,
            nameReencryptor: storage,
            finalizer: finalizer
        )
    }

    internal func makeNameDiscoverer() -> RecursiveValidNameDiscoverer {
        RecursiveValidNameDiscoverer(hashChecker: cloudSlot)
    }

    internal func makeAttributesCreator(_ draft: FileDraft) -> CryptoExtendedAttributesCreator {
        CryptoExtendedAttributesCreator(url: draft.url, maxBlockSize: Constants.maxBlockSize)
    }

    internal func makeFileDraftUploaderFinalizer(_ draft: FileDraft, _ attributesCreator: ExtendedAttributesCreator) -> LocalFileDraftUploaderFinalizer {
        LocalFileDraftUploaderFinalizer(draft: draft, storage: storage, xAttributesCreator: attributesCreator)
    }

}
