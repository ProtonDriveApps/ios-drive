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
        self.init(encryptedThumbnail: model.encrypted, decryptor: decryptor, identifier: model.revisionId.nodeIdentifier)
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
    let store: NodeStore
    let thumbnailRepository: ThumbnailRepository

    private var isCancelled = false

    init(store: NodeStore, thumbnailRepository: ThumbnailRepository) {
        self.store = store
        self.thumbnailRepository = thumbnailRepository
    }

    func decrypt(
        _ encrypted: Data,
        completion: @escaping ThumbnailOperationsFactory.Completion
    ) {
        guard !isCancelled else { return }

        let moc = store.backgroundContext
        moc.perform { [weak self] in
            guard let self = self else { return }

            do {
                let thumbnail = try self.getThumbnail(in: moc)
                thumbnail.encrypted = encrypted
                thumbnail.downloadURL = nil
                thumbnail.clearData = thumbnail.clearThumbnail

                try moc.saveOrRollback()
                completion(.success)

            } catch {
                Log.error(error: DriveError(error), domain: .encryption)
                completion(.failure(ThumbnailLoaderError.nonRecoverable))
            }
        }
    }

    private func getThumbnail(in moc: NSManagedObjectContext) throws -> Thumbnail {
        let thumbnail = try thumbnailRepository.getThumbnail()
        return thumbnail.in(moc: moc)
    }

    func cancel() {
        isCancelled = true
    }
}
