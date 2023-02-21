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

import CoreData

class ThumbnailDecryptorOperation: ThumbnailIdentifiableOperation {
    private var encryptedThumbnail: Data?
    private let decryptor: ThumbnailDecryptor

    init(encryptedThumbnail: Data?, decryptor: ThumbnailDecryptor, identifier: NodeIdentifier) {
        self.encryptedThumbnail = encryptedThumbnail
        self.decryptor = decryptor
        super.init(identifier: identifier)
    }

    convenience init(model: FullThumbnail, decryptor: ThumbnailDecryptor) {
        self.init(encryptedThumbnail: model.encrypted, decryptor: decryptor, identifier: model.id.nodeIdentifier)
    }

    override func main() {
        guard !isCancelled,
              let encryptedThumbnail = encryptedThumbnail else {
            return
        }

        decrypt(encryptedThumbnail)
    }

    func decrypt(_ encryptedThumbnail: Data) {
        guard !isCancelled else { return }

        decryptor.decrypt(encryptedThumbnail) { [weak self] result in
            guard let self = self,
                  !self.isCancelled else {
                return
            }

            switch result {
            case .success:
                self.finishOperationWithSuccess()

            case .failure(let error):
                self.finishOperationWithFailure(error)
            }
        }
    }

    override func cancel() {
        super.cancel()
        decryptor.cancel()
    }
}

final class ThumbnailDecryptor {
    let identifier: NodeIdentifier
    let store: NodeStore

    private var isCancelled = false

    init(identifier: NodeIdentifier, store: NodeStore) {
        self.identifier = identifier
        self.store = store
    }

    func decrypt(
        _ encrypted: Data,
        completion: @escaping ThumbnailOperationsFactory.Completion
    ) {
        guard !isCancelled else { return }

        let moc = store.backgroundContext
        moc.performAndWait {

            do {
                let thumbnail = try getThumbnail(in: moc)
                thumbnail.encrypted = encrypted
                thumbnail.downloadURL = nil
                thumbnail.clearData = thumbnail.clearThumbnail

                try moc.save()
                completion(.success)

            } catch {
                ConsoleLogger.shared?.log(DriveError(error, "ThumbnailDecryptor"))
                completion(.failure(ThumbnailLoaderError.nonRecoverable))
            }
        }
    }

    private func getThumbnail(in moc: NSManagedObjectContext) throws -> Thumbnail {
        guard let node = self.store.fetchNode(id: identifier, moc: moc),
              let file = node as? File,
              let revision = file.activeRevision ?? file.activeRevisionDraft,
              let thumbnail = revision.thumbnail else {
            throw ThumbnailLoaderError.nonRecoverable
        }
        return thumbnail
    }

    func cancel() {
        isCancelled = true
    }
}
