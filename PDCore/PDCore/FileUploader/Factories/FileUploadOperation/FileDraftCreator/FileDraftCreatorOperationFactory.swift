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

class FileDraftCreatorOperationFactory: FileUploadOperationFactory {

    let hashChecker: AvailableHashChecker
    let fileDraftCreator: CloudFileDraftCreator
    let sessionVault: SessionVault
    let storage: StorageManager

    init(
        hashChecker: AvailableHashChecker,
        fileDraftCreator: CloudFileDraftCreator,
        sessionVault: SessionVault,
        storage: StorageManager
    ) {
        self.hashChecker = hashChecker
        self.fileDraftCreator = fileDraftCreator
        self.sessionVault = sessionVault
        self.storage = storage
    }

    func make(from draft: FileDraft, completion: @escaping OnUploadCompletion) -> any UploadOperation {
        FileDraftUploaderOperation(
            unitOfWork: 100,
            draft: draft,
            fileDraftUploader: makeFileDraftUploader(),
            onError: { completion(.failure($0)) }
        )
    }

    func makeFileDraftUploader() -> FileDraftUploader {
        let nameDiscoverer = makeNameDiscoverer()
        return NameClashResolvingFileDraftUploader(
            cloudFileCreator: fileDraftCreator,
            validNameDiscoverer: nameDiscoverer,
            signersKitFactory: sessionVault,
            nameReencryptor: storage
        )
    }

    func makeNameDiscoverer() -> RecursiveValidNameDiscoverer {
        RecursiveValidNameDiscoverer(hashChecker: hashChecker)
    }

}
