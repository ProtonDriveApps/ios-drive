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

    private let fileDraftUploaderOperationFactory: FileDraftUploaderOperationFactory
    private let revisionCreatorOperationFactory: RevisionCreatorOperationFactory
    private let revisionEncryptorOperationFactory: EncryptRevisionOperationFactory
    private let revisionUploaderOperationFactory: RevisionUploaderOperationFactory
    private let revisionSealerOperationFactory: RevisionSealerOperationFactory
    private let completedStepsFileUploadOperationFactory: CompletedStepsFileUploadOperationFactory
    private let mainFileUploaderOperationFactory: MainFileUploaderOperationFactory

    private let weights: FileUploadWeights = .default

    init(
        fileDraftUploaderOperationFactory: FileDraftUploaderOperationFactory,
        revisionCreatorOperationFactory: RevisionCreatorOperationFactory,
        revisionEncryptorOperationFactory: EncryptRevisionOperationFactory,
        revisionUploaderOperationFactory: RevisionUploaderOperationFactory,
        revisionSealerOperationFactory: RevisionSealerOperationFactory,
        completedStepsFileUploadOperationFactory: CompletedStepsFileUploadOperationFactory,
        mainFileUploaderOperationFactory: MainFileUploaderOperationFactory
    ) {
        self.fileDraftUploaderOperationFactory = fileDraftUploaderOperationFactory
        self.revisionCreatorOperationFactory = revisionCreatorOperationFactory
        self.revisionEncryptorOperationFactory = revisionEncryptorOperationFactory
        self.revisionUploaderOperationFactory = revisionUploaderOperationFactory
        self.revisionSealerOperationFactory = revisionSealerOperationFactory
        self.completedStepsFileUploadOperationFactory = completedStepsFileUploadOperationFactory
        self.mainFileUploaderOperationFactory = mainFileUploaderOperationFactory
    }

    func getOperations(for file: FileDraft, onError: @escaping OnError, onSuccess: @escaping OnUploadSuccess) -> [Operation] {
        switch file.state {
        case .uploadingDraft:
            return uploadingFileDraftOperations(file: file, onError: onError, onSuccess: onSuccess)

        case .encryptingRevision:
            return encryptingRevisionOperations(file: file, onError: onError, onSuccess: onSuccess)

        case .uploadingRevision:
            return uploadingRevisionOperations(file: file, onError: onError, onSuccess: onSuccess)

        case .sealingRevision:
            return sealingRevisionOperations(file: file, onError: onError, onSuccess: onSuccess)

        case .updateRevision:
            return updateRevisionOperations(file: file, onError: onError, onSuccess: onSuccess)

        case .finished:
            assert(false, "iOS does not support uploading new revisions yet")
            return []
        }
    }

    private func uploadingFileDraftOperations(file: FileDraft, onError: @escaping OnError, onSuccess: @escaping OnUploadSuccess) -> [Operation] {
        let contentOperations = (file.numberOfBlocks + 1)
        let draftUploadUOW = weights.draftUpload
        let revisionEncryptionUOW = weights.revisionEncryption * contentOperations
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = draftUploadUOW + revisionEncryptionUOW + revisionUploaderUOW + revisionSealerUOW

        let fileDraftUploaderOperation = fileDraftUploaderOperationFactory.make(from: file, onError: onError)
        let revisionEncryptorOperation = revisionEncryptorOperationFactory.make(elements: contentOperations, draft: file, onError: onError)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(draft: file, onError: onError)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, onError: onError)
        let mainFileUploadOperation = mainFileUploaderOperationFactory.make(draft: file, onSuccess: onSuccess)

        revisionEncryptorOperation.addDependency(fileDraftUploaderOperation)
        revisionUploaderOperation.addDependency(revisionEncryptorOperation)
        revisionSealerOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            fileDraftUploaderOperation,
            revisionEncryptorOperation,
            revisionUploaderOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(fileDraftUploaderOperation.progress, pending: draftUploadUOW)
        mainFileUploaderProgress.addChild(revisionEncryptorOperation.progress, pending: revisionEncryptionUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return [
            fileDraftUploaderOperation,
            revisionEncryptorOperation,
            revisionUploaderOperation,
            revisionSealerOperation,
            mainFileUploadOperation
        ]
    }

    private func encryptingRevisionOperations(file: FileDraft, onError: @escaping OnError, onSuccess: @escaping OnUploadSuccess) -> [Operation] {
        let contentOperations = (file.numberOfBlocks + 1)
        let completedWorkProgress = weights.draftUpload
        let revisionEncryptionUOW = weights.revisionEncryption * contentOperations
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionEncryptionUOW + revisionUploaderUOW + revisionSealerUOW

        let completedWorkOperation = completedStepsFileUploadOperationFactory.make()
        let revisionEncryptorOperation = revisionEncryptorOperationFactory.make(elements: contentOperations, draft: file, onError: onError)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(draft: file, onError: onError)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, onError: onError)
        let mainFileUploadOperation = mainFileUploaderOperationFactory.make(draft: file, onSuccess: onSuccess)

        revisionEncryptorOperation.addDependency(completedWorkOperation)
        revisionUploaderOperation.addDependency(revisionEncryptorOperation)
        revisionSealerOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            revisionEncryptorOperation,
            revisionUploaderOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(revisionEncryptorOperation.progress, pending: revisionEncryptionUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return [
            completedWorkOperation,
            revisionEncryptorOperation,
            revisionUploaderOperation,
            revisionSealerOperation,
            mainFileUploadOperation
        ]
    }

    private func uploadingRevisionOperations(file: FileDraft, onError: @escaping OnError, onSuccess: @escaping OnUploadSuccess) -> [Operation] {
        let contentOperations = (file.numberOfBlocks + 1)
        let completedWorkProgress = weights.draftUpload + weights.revisionEncryption * contentOperations
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionUploaderUOW + revisionSealerUOW

        let completedWorkOperation = completedStepsFileUploadOperationFactory.make()
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(draft: file, onError: onError)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, onError: onError)
        let mainFileUploadOperation = mainFileUploaderOperationFactory.make(draft: file, onSuccess: onSuccess)

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

        return [
            completedWorkOperation,
            revisionUploaderOperation,
            revisionSealerOperation,
            mainFileUploadOperation
        ]
    }

    private func sealingRevisionOperations(file: FileDraft, onError: @escaping OnError, onSuccess: @escaping OnUploadSuccess) -> [Operation] {
        let contentOperations = (file.numberOfBlocks + 1)
        let completedWorkProgress = weights.draftUpload + weights.revisionEncryption * contentOperations + weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = completedWorkProgress + revisionSealerUOW

        let completedWorkOperation = completedStepsFileUploadOperationFactory.make()
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, onError: onError)
        let mainFileUploadOperation = mainFileUploaderOperationFactory.make(draft: file, onSuccess: onSuccess)

        revisionSealerOperation.addDependency(completedWorkOperation)
        mainFileUploadOperation.addDependencies([
            completedWorkOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(completedWorkOperation.progress, pending: completedWorkProgress)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return [
            completedWorkOperation,
            revisionSealerOperation,
            mainFileUploadOperation
        ]
    }

    private func updateRevisionOperations(file: FileDraft, onError: @escaping OnError, onSuccess: @escaping OnUploadSuccess) -> [Operation] {
        let contentOperations = (file.numberOfBlocks + 1)
        let updateRevisionUOW = weights.revisionUpdate
        let revisionEncryptionUOW = weights.revisionEncryption * contentOperations
        let revisionUploaderUOW = weights.revisionUploader * contentOperations
        let revisionSealerUOW = weights.revisionSealer
        let total: UnitOfWork = updateRevisionUOW + revisionEncryptionUOW + revisionUploaderUOW + revisionSealerUOW

        let createRevisionOperation = revisionCreatorOperationFactory.make(from: file, onError: onError)
        let revisionEncryptorOperation = revisionEncryptorOperationFactory.make(elements: contentOperations, draft: file, onError: onError)
        let revisionUploaderOperation = revisionUploaderOperationFactory.make(draft: file, onError: onError)
        let revisionSealerOperation = revisionSealerOperationFactory.make(from: file, onError: onError)
        let mainFileUploadOperation = mainFileUploaderOperationFactory.make(draft: file, onSuccess: onSuccess)

        revisionEncryptorOperation.addDependency(createRevisionOperation)
        revisionUploaderOperation.addDependency(revisionEncryptorOperation)
        revisionSealerOperation.addDependency(revisionUploaderOperation)
        mainFileUploadOperation.addDependencies([
            createRevisionOperation,
            revisionEncryptorOperation,
            revisionUploaderOperation,
            revisionSealerOperation,
            revisionSealerOperation
        ])

        let mainFileUploaderProgress = mainFileUploadOperation.progress
        mainFileUploaderProgress.totalUnitsOfWork = total
        mainFileUploaderProgress.addChild(createRevisionOperation.progress, pending: updateRevisionUOW)
        mainFileUploaderProgress.addChild(revisionEncryptorOperation.progress, pending: revisionEncryptionUOW)
        mainFileUploaderProgress.addChild(revisionUploaderOperation.progress, pending: revisionUploaderUOW)
        mainFileUploaderProgress.addChild(revisionSealerOperation.progress, pending: revisionSealerUOW)

        return [
            createRevisionOperation,
            revisionEncryptorOperation,
            revisionUploaderOperation,
            revisionSealerOperation,
            mainFileUploadOperation
        ]
    }
}
