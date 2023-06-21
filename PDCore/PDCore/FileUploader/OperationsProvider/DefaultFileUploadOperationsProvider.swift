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

final class DefaultFileUploadOperationsProvider: FileUploadOperationsProvider {

    private let revisionEncryptorOperationFactory: FileUploadOperationFactory
    private let fileDraftUploaderOperationFactory: FileUploadOperationFactory
    private let revisionCreatorOperationFactory: FileUploadOperationFactory
    private let revisionUploaderOperationFactory: FileUploadOperationFactory
    private let revisionSealerOperationFactory: FileUploadOperationFactory

    private let weights: FileUploadWeights = .default

    init(
        revisionEncryptorOperationFactory: FileUploadOperationFactory,
        fileDraftUploaderOperationFactory: FileUploadOperationFactory,
        revisionCreatorOperationFactory: FileUploadOperationFactory,
        revisionUploaderOperationFactory: FileUploadOperationFactory,
        revisionSealerOperationFactory: FileUploadOperationFactory
    ) {
        self.fileDraftUploaderOperationFactory = fileDraftUploaderOperationFactory
        self.revisionCreatorOperationFactory = revisionCreatorOperationFactory
        self.revisionEncryptorOperationFactory = revisionEncryptorOperationFactory
        self.revisionUploaderOperationFactory = revisionUploaderOperationFactory
        self.revisionSealerOperationFactory = revisionSealerOperationFactory
    }

    func getOperations(for draft: FileDraft, completion: @escaping OnUploadCompletion) -> any UploadOperation {
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

    private func encryptingRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> MainFileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let revisionEncryptionUOW = weights.revisionEncryption * contentOperations
        let draftUploadUOW = weights.draftUpload
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = revisionEncryptionUOW + draftUploadUOW + revisionUploaderUOW + revisionSealerUOW

        let revisionEncryptorOperation = revisionEncryptorOperationFactory.make(from: file, completion: completion)
        let fileDraftUploaderOperation = fileDraftUploaderOperationFactory.make(from: file, completion: completion)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        fileDraftUploaderOperation.addDependency(revisionEncryptorOperation)
        revisionUploaderOperation.addDependency(fileDraftUploaderOperation)
        revisionSealerOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            revisionEncryptorOperation,
            fileDraftUploaderOperation,
            revisionUploaderOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(revisionEncryptorOperation.progress, pending: revisionEncryptionUOW)
        mainFileUploaderProgress.addChild(fileDraftUploaderOperation.progress, pending: draftUploadUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    private func creatingFileDraftOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> MainFileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let completedWorkProgress = weights.revisionEncryption * contentOperations
        let draftUploadUOW = weights.draftUpload
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + draftUploadUOW + revisionUploaderUOW + revisionSealerUOW

        let completedWorkOperation = makeCompletedStepsOperation()
        let fileDraftUploaderOperation = fileDraftUploaderOperationFactory.make(from: file, completion: completion)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        fileDraftUploaderOperation.addDependency(completedWorkOperation)
        revisionUploaderOperation.addDependency(fileDraftUploaderOperation)
        revisionSealerOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            fileDraftUploaderOperation,
            revisionUploaderOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(fileDraftUploaderOperation.progress, pending: draftUploadUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    private func uploadingRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> MainFileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let completedWorkProgress = weights.revisionEncryption * contentOperations + weights.draftUpload
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionUploaderUOW + revisionSealerUOW

        let completedWorkOperation = makeCompletedStepsOperation()
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        revisionUploaderOperation.addDependency(completedWorkOperation)
        revisionSealerOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            revisionUploaderOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    private func commitingRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> MainFileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let completedWorkProgress = weights.draftUpload + weights.revisionEncryption * contentOperations + weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionSealerUOW

        let completedWorkOperation = makeCompletedStepsOperation()
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        revisionSealerOperation.addDependency(completedWorkOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    private func encryptingNewRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> MainFileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let revisionEncryptionUOW = weights.revisionEncryption * contentOperations
        let revisionCreatorUOW = weights.revisionUpdate
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = revisionEncryptionUOW + revisionCreatorUOW + revisionUploaderUOW + revisionSealerUOW

        let revisionEncryptorOperation = revisionEncryptorOperationFactory.make(from: file, completion: completion)
        let revisionCreatorOperation = revisionCreatorOperationFactory.make(from: file, completion: completion)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        revisionCreatorOperation.addDependency(revisionEncryptorOperation)
        revisionUploaderOperation.addDependency(revisionCreatorOperation)
        revisionSealerOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            revisionEncryptorOperation,
            revisionCreatorOperation,
            revisionUploaderOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(revisionEncryptorOperation.progress, pending: revisionEncryptionUOW)
        mainFileUploaderProgress.addChild(revisionCreatorOperation.progress, pending: revisionCreatorUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    private func creatingNewRevisionOperations(file: FileDraft, completion: @escaping OnUploadCompletion) -> MainFileUploaderOperation {
        let contentOperations = (file.numberOfBlocks + 2)
        let completedWorkProgress = weights.revisionEncryption * contentOperations
        let revisionCreatorUOW = weights.revisionUpdate
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionCreatorUOW + revisionUploaderUOW + revisionSealerUOW

        let completedWorkOperation = makeCompletedStepsOperation()
        let createRevisionOperation = revisionCreatorOperationFactory.make(from: file, completion: completion)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(from: file, completion: completion)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, completion: completion)
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)

        createRevisionOperation.addDependency(completedWorkOperation)
        revisionUploaderOperation.addDependency(createRevisionOperation)
        revisionSealerOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            createRevisionOperation,
            revisionUploaderOperation,
            revisionSealerOperation,
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(createRevisionOperation.progress, pending: revisionCreatorUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return mainFileUploadOperation
    }

    private func creatingFailingUploadOperation(file: FileDraft, completion: @escaping OnUploadCompletion) -> MainFileUploaderOperation  {
        let mainFileUploadOperation = makeMainFileUploadOperation(from: file, completion: completion)
        let failingOperation = makeFailureCompletingOperation(from: file, completion: completion)

        mainFileUploadOperation.addDependency(failingOperation)
        mainFileUploadOperation.progress.addChild(failingOperation.progress, pending: 1)

        return mainFileUploadOperation
    }

    private func makeCompletedStepsOperation() -> OperationWithProgress {
        ImmediatelyFinishingOperation()
    }

    private func makeFailureCompletingOperation(from draft: FileDraft, completion: @escaping OnUploadCompletion) -> OperationWithProgress {
        let error = draft.file.invalidState("This file is not in a valid uploading state ⚠️.")
        return CompletionExecutingOperation(uploadID: draft.uploadID, onCompletion: { completion(.failure(error)) })
    }

    private func makeMainFileUploadOperation(from file: FileDraft, completion: @escaping OnUploadCompletion) -> MainFileUploaderOperation {
        return MainFileUploaderOperation(draft: file, onSuccess: { completion(.success($0)) })
    }
}
