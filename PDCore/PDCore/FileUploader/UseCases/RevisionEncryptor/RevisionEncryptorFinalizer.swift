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

protocol RevisionEncryptionFinalizer {
    typealias RevisionEncryptionCompletion = (Result<Void, Error>) -> Void
    func finalize(revision: Revision, completion: @escaping RevisionEncryptionCompletion)
}

extension StorageManager: RevisionEncryptionFinalizer {
    func finalize(revision: Revision, completion: @escaping RevisionEncryptionCompletion) {
        guard let moc = revision.moc else { return }

        moc.performAndWait {
            revision.uploadState = .encrypted
            revision.file.state = .uploading

            do {
                try moc.save()
                completion(.success)
            } catch {
                moc.rollback()
                completion(.failure(error))
            }
        }
    }
}
