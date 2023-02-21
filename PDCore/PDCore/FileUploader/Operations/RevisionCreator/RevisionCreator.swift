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
        ConsoleLogger.shared?.log("STAGE: 1 Create revision 🐣📦🏞 started", osLogType: FileUploader.self)
        creator.createRevision(for: draft.file.identifier) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success(let revision):
                ConsoleLogger.shared?.log("STAGE: 1 Create revision 🐣📦🏞 finished ✅", osLogType: FileUploader.self)
                try? self.finalizer.finalize(identifier: revision)
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
    func finalize(identifier: RevisionIdentifier) throws
}

extension StorageManager: LocalRevisionCreatorFinalizer {

    func finalize(identifier: RevisionIdentifier) throws {
        guard let file: File = existing(with: Set([identifier.file]), in: backgroundContext).first else {
            fatalError("A file valid file must be present before Revision creation")
        }

        try backgroundContext.performAndWait {
            let revision: Revision = new(with: identifier.revision, by: "id", in: backgroundContext)

            file.activeRevisionDraft = revision

            revision.file = file
            revision.uploadState = .created

            do {
                try backgroundContext.save()
            } catch {
                backgroundContext.rollback()
                throw error
            }
        }
    }
}
