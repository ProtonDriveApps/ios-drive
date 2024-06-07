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
import CoreData

final class FileRevisionDraftCreator: RevisionDraftCreator {
    private let creator: CloudRevisionCreator
    private let moc: NSManagedObjectContext
    private var isCancelled = false

    init(creator: CloudRevisionCreator, moc: NSManagedObjectContext) {
        self.creator = creator
        self.moc = moc
    }

    func create(_ draft: FileDraft, completion: @escaping RevisionDraftCreator.Completion) {
        guard !isCancelled else { return }

        do {
            let identifier = try draft.getFileIdentifier()
            creator.createRevision(for: identifier) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                switch result {
                case .success(let revisionIdentifier):
                    do {
                        try self.finalize(draft, with: revisionIdentifier)
                        completion(.success)
                    } catch {
                        completion(.failure(error))
                    }

                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func cancel() {
        isCancelled = true
    }

    private func finalize(_ draft: FileDraft, with revisionIdentifier: RevisionIdentifier) throws {
        try moc.performAndWait {
            guard let revision = draft.file.activeRevisionDraft else {
                throw draft.file.invalidState("The file should have an active revisionDraft")
            }

            revision.id = revisionIdentifier.revision

            try moc.saveOrRollback()
        }
    }
}
