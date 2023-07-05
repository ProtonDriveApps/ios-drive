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

class DefaultFileDraftCreatorOperationFactory: FileUploadOperationFactory {
    let fileDraftCreator: CloudFileDraftCreator
    let sessionVault: SessionVault
    
    init(
        fileDraftCreator: CloudFileDraftCreator,
        sessionVault: SessionVault
    ) {
        self.fileDraftCreator = fileDraftCreator
        self.sessionVault = sessionVault
    }

    func make(from draft: FileDraft, completion: @escaping OnUploadCompletion) -> any UploadOperation {
        FileDraftCreatorOperation(
            unitOfWork: 100,
            draft: draft,
            fileDraftCreator: makeFileDraftCreator(),
            onError: { completion(.failure($0)) }
        )
    }
    
    func makeFileDraftCreator() -> FileDraftCreator {
        return DefaultFileDraftCreator(
            cloudFileCreator: fileDraftCreator,
            signersKitFactory: sessionVault
        )
    }
}
