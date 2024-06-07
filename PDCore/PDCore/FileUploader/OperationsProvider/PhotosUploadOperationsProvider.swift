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

class PhotosUploadOperationsProvider: MyFilesFileUploadOperationsProvider {
    override func getOperations(for draft: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        switch draft.state {
        case .encryptingRevision:
            return encryptingRevisionOperations(file: draft, completion: completion)

        case .creatingFileDraft:
            return creatingFileDraftOperations(file: draft, completion: completion)

        case .uploadingRevision:
            return uploadingRevisionOperations(file: draft, completion: completion)

        case .commitingRevision:
            return commitingRevisionOperations(file: draft, completion: completion)

        case .encryptingNewRevision, .creatingNewRevision:
            return creatingFailingUploadOperation(file: draft, completion: completion)

        case .none:
            return creatingFinisherMainFileUploadOperation(file: draft, completion: completion)
        }
    }

    func creatingFinisherMainFileUploadOperation(file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation  {
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)
        let completedStepsOperation = makeCompletedStepsOperation(file.uploadID)

        mainFileUploadOperation.addDependency(completedStepsOperation)
        mainFileUploadOperation.progress.addChild(completedStepsOperation.progress, pending: 1)

        return mainFileUploadOperation
    }

    override func makeMainFileUploadOperation(from file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        return PhotoUploaderOperation(draft: file, onSuccess: { completion(.success($0)) })
    }
}
