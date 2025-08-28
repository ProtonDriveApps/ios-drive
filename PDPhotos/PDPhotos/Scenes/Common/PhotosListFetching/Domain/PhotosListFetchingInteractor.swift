// Copyright (c) 2025 Proton AG
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

import Combine
import Foundation
import PDCore
import PDClient

struct PhotosListFetchingInput: Equatable {
    let anchorId: String?
    let tag: PhotoTag?
    let isResetting: Bool
}

struct PhotosListFetchingResponse: Equatable {
    let input: PhotosListFetchingInput
    let photos: [RemotePhotoListing]
    let anchorId: String?
    let hasMore: Bool
    let captureTimeThreshold: Date?

    var anchor: PhotosListFetchingAnchor {
        PhotosListFetchingAnchor(
            anchorId: anchorId,
            hasMore: hasMore,
            captureTimeThreshold: captureTimeThreshold,
            hasPhotos: !photos.isEmpty || input.anchorId != nil
        )
    }
}

struct PhotosListFetchingAnchor: Equatable, Codable {
    let anchorId: String?
    let hasMore: Bool
    let captureTimeThreshold: Date?
    let hasPhotos: Bool
}

protocol PhotosListFetchingInteractorProtocol {
    func execute(with input: PhotosListFetchingInput) async throws -> PhotosListFetchingResponse
}

final class PhotosListFetchingInteractor: ThrowingAsynchronousInteractor, PhotosListFetchingInteractorProtocol {
    private let configuration: PhotosListConfiguration
    private let remoteListingRepository: RemotePhotosListingRepository
    private let storeListingRepository: StorePhotoListingsRepository
    private static let pageSize = 500

    init(configuration: PhotosListConfiguration, remoteListingRepository: RemotePhotosListingRepository, storeListingRepository: StorePhotoListingsRepository) {
        self.configuration = configuration
        self.remoteListingRepository = remoteListingRepository
        self.storeListingRepository = storeListingRepository
    }

    func execute(with input: PhotosListFetchingInput) async throws -> PhotosListFetchingResponse {
        if let albumId = configuration.albumId {
            return try await fetchAndStoreAlbumPhotos(input: input, albumId: albumId)
        } else {
            return try await fetchAndStoreStreamPhotos(input: input)
        }
    }

    private func fetchAndStoreStreamPhotos(input: PhotosListFetchingInput) async throws -> PhotosListFetchingResponse {
        let parameters = PhotosListRequestParameters(
            volumeId: configuration.volumeId,
            lastId: input.anchorId,
            pageSize: PhotosListFetchingInteractor.pageSize,
            tag: input.tag?.rawValue
        )
        let remoteList = try await remoteListingRepository.getPhotosList(with: parameters)
        let storeData = StorePhotoListingsData(
            listings: remoteList.photos,
            volumeId: configuration.volumeId,
            type: .stream(tag: input.tag),
            isResetting: input.isResetting
        )
        try await storeListingRepository.storeListings(data: storeData)
        return PhotosListFetchingResponse(
            input: input,
            photos: remoteList.photos,
            anchorId: remoteList.photos.last?.linkID ?? input.anchorId,
            hasMore: !remoteList.photos.isEmpty,
            captureTimeThreshold: remoteList.photos.isEmpty ? nil : getTimeThreshold(from: remoteList.photos)
        )
    }

    private func fetchAndStoreAlbumPhotos(input: PhotosListFetchingInput, albumId: String) async throws -> PhotosListFetchingResponse {
        let parameters = ListPhotosInAlbumRequest.Parameters(
            volumeID: configuration.volumeId,
            linkID: albumId,
            anchorID: input.anchorId
        )
        let remoteList = try await remoteListingRepository.listPhotosInAlbum(parameters: parameters)
        let storeData = StorePhotoListingsData(
            listings: remoteList.photos,
            volumeId: configuration.volumeId,
            type: .album(albumId: albumId),
            isResetting: input.isResetting
        )
        try await storeListingRepository.storeListings(data: storeData)
        return PhotosListFetchingResponse(
            input: input,
            photos: remoteList.photos,
            anchorId: remoteList.anchorID,
            hasMore: remoteList.more,
            captureTimeThreshold: getTimeThreshold(from: remoteList.photos)
        )
    }

    private func getTimeThreshold(from photos: [RemotePhotoListing]) -> Date? {
        let offset = 70
        let index = photos.count > offset ? photos.count - 70 : 0
        guard let timestamp = (photos[safe: index] ?? photos.first)?.captureTime else {
            return nil
        }
        return Date(timeIntervalSince1970: Double(timestamp))
    }
}
