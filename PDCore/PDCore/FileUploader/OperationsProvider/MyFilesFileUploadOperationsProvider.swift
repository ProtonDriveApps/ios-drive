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

class MyFilesFileUploadOperationsProvider: FileUploadOperationsProvider {

    private let revisionEncryptorOperationFactory: FileUploadOperationFactory
    private let fileDraftCreatorOperationFactory: FileUploadOperationFactory
    private let revisionCreatorOperationFactory: FileUploadOperationFactory
    private let revisionUploaderOperationFactory: FileUploadOperationFactory
    private let revisionCommitterOperationFactory: FileUploadOperationFactory

    private let weights: FileUploadWeights = .default

    init(
        revisionEncryptorOperationFactory: FileUploadOperationFactory,
        fileDraftCreatorOperationFactory: FileUploadOperationFactory,
        revisionCreatorOperationFactory: FileUploadOperationFactory,
        revisionUploaderOperationFactory: FileUploadOperationFactory,
        revisionCommitterOperationFactory: FileUploadOperationFactory
    ) {
        self.fileDraftCreatorOperationFactory = fileDraftCreatorOperationFactory
        self.revisionCreatorOperationFactory = revisionCreatorOperationFactory
        self.revisionEncryptorOperationFactory = revisionEncryptorOperationFactory
        self.revisionUploaderOperationFactory = revisionUploaderOperationFactory
        self.revisionCommitterOperationFactory = revisionCommitterOperationFactory
    }

    func getOperations(for draft: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        switch draft.state {
        case .encryptingRevision:
            return encryptingRevisionOperations(file: draft, completion: completion)

        case .creatingFileDraft:
            return creatingFileDraftOperations(file: draft, completion: completion)

        case .uploadingRevision:
            return uploadingRevisionOperations(file: draft, completion: completion)

        case .commitingRevision:
            return commitingRevisionOperations(file: draft, completion: completion)

        case .encryptingNewRevision:
            return encryptingNewRevisionOperations(file: draft, completion: completion)

        case .creatingNewRevision:
            return creatingNewRevisionOperations(file: draft, completion: completion)

        case .none:
            return creatingFailingUploadOperation(file: draft, completion: completion)
        }
    }

    func encryptingRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let revisionEncryptionUOW = weights.revisionEncryption * contentOperations
        let draftUploadUOW = weights.draftUpload
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = revisionEncryptionUOW + draftUploadUOW + revisionUploaderUOW + revisionSealerUOW

        let revisionEncryptorOperation = revisionEncryptorOperationFactory.make(from: file, completion: completion)
        let fileDraftCreatorOperation = fileDraftCreatorOperationFactory.make(from: file, completion: completion)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionCommitterOperation = revisionCommitterOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        fileDraftCreatorOperation.addDependency(revisionEncryptorOperation)
        revisionUploaderOperation.addDependency(fileDraftCreatorOperation)
        revisionCommitterOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            revisionEncryptorOperation,
            fileDraftCreatorOperation,
            revisionUploaderOperation,
            revisionCommitterOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(revisionEncryptorOperation.progress, pending: revisionEncryptionUOW)
        mainFileUploaderProgress.addChild(fileDraftCreatorOperation.progress, pending: draftUploadUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionCommitterOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    func creatingFileDraftOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let completedWorkProgress = weights.revisionEncryption * contentOperations
        let draftUploadUOW = weights.draftUpload
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + draftUploadUOW + revisionUploaderUOW + revisionSealerUOW

        let completedWorkOperation = makeCompletedStepsOperation(file.uploadID)
        let fileDraftCreatorOperation = fileDraftCreatorOperationFactory.make(from: file, completion: completion)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionCommitterOperation = revisionCommitterOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        fileDraftCreatorOperation.addDependency(completedWorkOperation)
        revisionUploaderOperation.addDependency(fileDraftCreatorOperation)
        revisionCommitterOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            fileDraftCreatorOperation,
            revisionUploaderOperation,
            revisionCommitterOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(fileDraftCreatorOperation.progress, pending: draftUploadUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionCommitterOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    func uploadingRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let completedWorkProgress = weights.revisionEncryption * contentOperations + weights.draftUpload
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionUploaderUOW + revisionSealerUOW

        let completedWorkOperation = makeCompletedStepsOperation(file.uploadID)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionCommitterOperation = revisionCommitterOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        revisionUploaderOperation.addDependency(completedWorkOperation)
        revisionCommitterOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            revisionUploaderOperation,
            revisionCommitterOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionCommitterOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    func commitingRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let completedWorkProgress = weights.draftUpload + weights.revisionEncryption * contentOperations + weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionSealerUOW

        let completedWorkOperation = makeCompletedStepsOperation(file.uploadID)
        let revisionCommitterOperation = revisionCommitterOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        revisionCommitterOperation.addDependency(completedWorkOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            revisionCommitterOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(revisionCommitterOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    func encryptingNewRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let revisionEncryptionUOW = weights.revisionEncryption * contentOperations
        let revisionCreatorUOW = weights.revisionUpdate
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = revisionEncryptionUOW + revisionCreatorUOW + revisionUploaderUOW + revisionSealerUOW

        let revisionEncryptorOperation = revisionEncryptorOperationFactory.make(from: file, completion: completion)
        let revisionCreatorOperation = revisionCreatorOperationFactory.make(from: file, completion: completion)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionCommitterOperation = revisionCommitterOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        revisionCreatorOperation.addDependency(revisionEncryptorOperation)
        revisionUploaderOperation.addDependency(revisionCreatorOperation)
        revisionCommitterOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            revisionEncryptorOperation,
            revisionCreatorOperation,
            revisionUploaderOperation,
            revisionCommitterOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(revisionEncryptorOperation.progress, pending: revisionEncryptionUOW)
        mainFileUploaderProgress.addChild(revisionCreatorOperation.progress, pending: revisionCreatorUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionCommitterOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    func creatingNewRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let completedWorkProgress = weights.revisionEncryption * contentOperations
        let revisionCreatorUOW = weights.revisionUpdate
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionCreatorUOW + revisionUploaderUOW + revisionSealerUOW

        let completedWorkOperation = makeCompletedStepsOperation(file.uploadID)
        let createRevisionOperation = revisionCreatorOperationFactory.make(from: file, completion: completion)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionCommitterOperation = revisionCommitterOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        createRevisionOperation.addDependency(completedWorkOperation)
        revisionUploaderOperation.addDependency(createRevisionOperation)
        revisionCommitterOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            createRevisionOperation,
            revisionUploaderOperation,
            revisionCommitterOperation,
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(createRevisionOperation.progress, pending: revisionCreatorUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionCommitterOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    func creatingFailingUploadOperation(file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation  {
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)
        let failingOperation = makeFailureCompletingOperation(from: file, completion: completion)

        mainFileUploadOperation.addDependency(failingOperation)
        mainFileUploadOperation.progress.addChild(failingOperation.progress, pending: 1)

        return mainFileUploadOperation
    }

    func makeCompletedStepsOperation(_ id: UUID) -> OperationWithProgress {
        ImmediatelyFinishingOperation(id: id)
    }

    func makeFailureCompletingOperation(from draft: FileDraft, completion: @escaping OnUploadCompletion) -> OperationWithProgress {
        let error = draft.file.invalidState("This file is not in a valid uploading state ⚠️.")
        return CompletionExecutingOperation(uploadID: draft.uploadID, onCompletion: { completion(.failure(error)) })
    }

    func makeMainFileUploadOperation(from file: FileDraft, completion: @escaping OnUploadCompletion) -> FileUploaderOperation {
        return FileUploaderOperation(draft: file, onSuccess: { completion(.success($0)) })
    }
}
