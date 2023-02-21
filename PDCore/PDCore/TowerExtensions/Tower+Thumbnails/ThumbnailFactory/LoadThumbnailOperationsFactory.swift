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

final class LoadThumbnailOperationsFactory: ThumbnailOperationsFactory {
    let store: StorageManager
    let cloud: ThumbnailCloudClient
    let session = URLSession(configuration: .ephemeral)

    init(store: StorageManager, cloud: ThumbnailCloudClient) {
        self.store = store
        self.cloud = cloud
    }

    func makeThumbnailModel(forFileWithID id: Identifier) throws -> ThumbnailIdentifiableOperation {
        let thumbnail = try makeThumbnail(fileID: id)

        switch thumbnail {
        case let fullThumbnail as FullThumbnail:
            let decryptor = ThumbnailDecryptor(identifier: fullThumbnail.id.nodeIdentifier, store: store)
            let operation = ThumbnailDecryptorOperation(model: fullThumbnail, decryptor: decryptor)
            return operation

        case let inProgressThumbnail as InProgressThumbnail:
            let downloader = URLSessionThumbnailDownloader(session: session)
            let decryptor = ThumbnailDecryptor(identifier: inProgressThumbnail.id.nodeIdentifier, store: store)
            let operation = DownloadThumbnailOperation(model: inProgressThumbnail, downloader: downloader, decryptor: decryptor)
            return operation

        case let incompleteThumbnail as IncompleteThumbnail:
            let downloader = URLSessionThumbnailDownloader(session: session)
            let decryptor = ThumbnailDecryptor(identifier: incompleteThumbnail.id.nodeIdentifier, store: store)
            let operation = IncompleteThumbnailDownloaderOperation(model: incompleteThumbnail, cloud: cloud, downloader: downloader, decryptor: decryptor)
            return operation

        default:
            throw ThumbnailLoaderError.nonRecoverable
        }
    }

    private func makeThumbnail(fileID: Identifier) throws -> ThumbnailModel {
        let moc = store.backgroundContext

        let model: ThumbnailModel = try  moc.performAndWait {
            let node = self.store.fetchNode(id: fileID, moc: moc)

            guard let file = node as? File else {
                throw ThumbnailLoaderError.nonRecoverable
            }

            guard let revision = file.latestRevision else {
                throw ThumbnailLoaderError.noValidRevision
            }

            let thumbnail = try getThumbnail(from: revision)

            return makeModel(thumbnail, id: revision.identifier)
        }

        return model
    }

    private func makeModel(_ thumbnail: Thumbnail, id: RevisionIdentifier) -> ThumbnailModel {
        if let data = thumbnail.encrypted {
            return FullThumbnail(id: id, encrypted: data)
        }

        if let urlString = thumbnail.downloadURL,
           let url = URL(string: urlString) {
            return InProgressThumbnail(id: id, url: url)
        }

        return IncompleteThumbnail(id: id)
    }

    private func getThumbnail(from revision: Revision) throws -> Thumbnail {
        if revision.uploadState == .created {
            throw ThumbnailLoaderError.thumbnailNotYetCreated
        }

        guard let thumbnail = revision.thumbnail else {
            throw ThumbnailLoaderError.nonRecoverable
        }

        return thumbnail
    }
}

private extension File {
    var latestRevision: Revision? {
        if let revision = activeRevision {
            return revision
        } else if let revision = activeRevisionDraft {
            return revision
        } else {
            return nil
        }
    }
}
