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

final class RevisionCreatorOperation: AsynchronousOperation, OperationWithProgress {

    let progress: Progress = Progress(unitsOfWork: 1)
    let draft: FileDraft
    let creator: CloudRevisionCreator
    let finalizer: LocalRevisionCreatorFinalizer
    let onError: OnError

    init(
        draft: FileDraft,
        creator: CloudRevisionCreator,
        finalizer: LocalRevisionCreatorFinalizer,
        onError: @escaping OnError
    ) {
        self.draft = draft
        self.creator = creator
        self.finalizer = finalizer
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        let file = draft.file
        ConsoleLogger.shared?.log("STAGE: 1 Create revision 🐣📦🏞 started", osLogType: FileUploader.self)
        creator.createRevision(for: file) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success(let revision):
                ConsoleLogger.shared?.log("STAGE: 1 Create revision 🐣📦🏞 finished ✅", osLogType: FileUploader.self)
                try? self.finalizer.finalize(file: file, revisionIdentifier: revision)
                self.progress.complete()
                self.state = .finished

            case .failure(let error):
                ConsoleLogger.shared?.log("STAGE: 1 Create revision 🐣📦🏞 finished ❌", osLogType: FileUploader.self)
                self.onError(error)
            }
        }
    }
}

protocol LocalRevisionCreatorFinalizer {
    func finalize(file: File, revisionIdentifier: RevisionIdentifier) throws
}

extension StorageManager: LocalRevisionCreatorFinalizer {

    func finalize(file: File, revisionIdentifier: RevisionIdentifier) throws {
        try backgroundContext.performAndWait {
            let file = file.in(moc: backgroundContext)
            guard let revision = file.activeRevisionDraft else {
                throw file.invalidState("The file should have an active revisionDraft")
            }

            revision.id = revisionIdentifier.revision
            revision.uploadState = .created

            try backgroundContext.saveOrRollback()
        }
    }
}
