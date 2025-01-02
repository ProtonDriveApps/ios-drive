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
import PDClient

final class LoadThumbnailOperationsFactory: ThumbnailOperationsFactory {
    let store: StorageManager
    let cloud: CloudSlotProtocol
    let client: PDClient.Client
    let session = URLSession.forUploading()
    private let thumbnailRepository: NodeThumbnailRepository
    private let typeStrategy: ThumbnailTypeStrategy

    init(store: StorageManager, cloud: CloudSlotProtocol, client: PDClient.Client, thumbnailRepository: NodeThumbnailRepository, typeStrategy: ThumbnailTypeStrategy) {
        self.store = store
        self.cloud = cloud
        self.client = client
        self.thumbnailRepository = thumbnailRepository
        self.typeStrategy = typeStrategy
    }

    func makeThumbnailModel(forFileWithID id: Identifier) throws -> ThumbnailIdentifiableOperation {
        let thumbnail = try makeThumbnail(fileID: id)

        switch thumbnail {
        case let .full(fullThumbnail):
            let decryptor = makeThumbnailDecryptor(identifier: fullThumbnail.revisionId.nodeIdentifier)
            let operation = ThumbnailDecryptorOperation(model: fullThumbnail, decryptor: decryptor)
            return operation

        case let .inProgress(inProgressThumbnail):
            let downloader = URLSessionThumbnailDownloader(session: session)
            let decryptor = makeThumbnailDecryptor(identifier: inProgressThumbnail.revisionId.nodeIdentifier)
            let urlFetchInteractor = ThumbnailsListFactory().makeRemoteURLFetchInteractor(client: client, cloudSlot: cloud)
            let operation = DownloadThumbnailOperation(model: inProgressThumbnail, downloader: downloader, decryptor: decryptor, urlFetchInteractor: urlFetchInteractor)
            return operation

        case let .revisionId(incompleteThumbnail):
            let downloader = URLSessionThumbnailDownloader(session: session)
            let decryptor = makeThumbnailDecryptor(identifier: incompleteThumbnail.revisionId.nodeIdentifier)
            let urlFetchInteractor = ThumbnailsListFactory().makeRemoteURLFetchInteractor(client: client, cloudSlot: cloud)
            let operation = IncompleteThumbnailDownloaderOperation(model: incompleteThumbnail, cloud: cloud, downloader: downloader, decryptor: decryptor, typeStrategy: typeStrategy, urlFetchInteractor: urlFetchInteractor)
            return operation

        case let .thumbnailId(thumbnailWithId):
            let downloader = URLSessionThumbnailDownloader(session: session)
            let decryptionResource = makeThumbnailDecryptor(thumbnail: thumbnailWithId)
            let urlFetchInteractor = ThumbnailsListFactory().makeRemoteURLFetchInteractor(client: client, cloudSlot: cloud)
            return ThumbnailIdentifierDownloadOperation(thumbnailWithId: thumbnailWithId, downloader: downloader, decryptor: decryptionResource, urlFetchInteractor: urlFetchInteractor)
        }
    }

    private func makeThumbnailDecryptor(identifier: NodeIdentifier) -> ThumbnailDecryptor {
        let thumbnailRepository = LegacyDatabaseThumbnailRepository(nodeIdentifier: identifier, repository: thumbnailRepository)
        return ThumbnailDecryptor(store: store, thumbnailRepository: thumbnailRepository)
    }

    private func makeThumbnailDecryptor(thumbnail: ThumbnailIdentifier) -> ThumbnailDecryptor {
        let thumbnailRepository = DatabaseThumbnailRepository(id: thumbnail, storage: store)
        return ThumbnailDecryptor(store: store, thumbnailRepository: thumbnailRepository)
    }

    private func makeThumbnail(fileID: Identifier) throws -> ThumbnailModel {
        let thumbnail = try thumbnailRepository.fetchThumbnail(fileID: fileID)
        
        guard let moc = thumbnail.moc else {
            throw ThumbnailLoaderError.nonRecoverable
        }

        return moc.performAndWait {
            makeModel(thumbnail)
        }
    }

    private func makeModel(_ thumbnail: Thumbnail) -> ThumbnailModel {
        let id = thumbnail.revision.identifier
        if let data = thumbnail.encrypted {
            return .full(FullThumbnail(revisionId: id, encrypted: data))
        }

        if let urlString = thumbnail.downloadURL,
           let url = URL(string: urlString) {
            let thumbnailIdentifier = makeThumbnailIdentififer(from: thumbnail)
            return .inProgress(InProgressThumbnail(revisionId: id, url: url, thumbnailIdentifier: thumbnailIdentifier))
        }

        if let thumbnailIdentifier = makeThumbnailIdentififer(from: thumbnail) {
            return .thumbnailId(thumbnailIdentifier)
        }

        return .revisionId(IncompleteThumbnail(revisionId: id))
    }

    private func makeThumbnailIdentififer(from thumbnail: Thumbnail) -> ThumbnailIdentifier? {
        if !thumbnail.volumeID.isEmpty {
            return ThumbnailIdentifier(thumbnailId: thumbnail.id, volumeId: thumbnail.volumeID, nodeIdentifier: thumbnail.revision.identifier.nodeIdentifier)
        } else {
            return nil
        }
    }

    private func getThumbnail(from revision: Revision) throws -> Thumbnail {
        if revision.uploadState == .created {
            throw ThumbnailLoaderError.thumbnailNotYetCreated
        }

        guard let thumbnail = revision.thumbnails.first else {
            throw ThumbnailLoaderError.nonRecoverable
        }

        return thumbnail
    }
}
