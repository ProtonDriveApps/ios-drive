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
import PDCore

final class PhotosMetadataLoadInteractor: ThrowingAsynchronousInteractor {
    private let shareIdDataSource: PhotoShareIdDataSource
    private let listing: PhotosListing
    private let updateRepository: LinksUpdateRepository
    private let oldestPhotoIdRepository: OldestPhotoIdRepository

    init(shareIdDataSource: PhotoShareIdDataSource, listing: PhotosListing, updateRepository: LinksUpdateRepository, oldestPhotoIdRepository: OldestPhotoIdRepository) {
        self.shareIdDataSource = shareIdDataSource
        self.listing = listing
        self.updateRepository = updateRepository
        self.oldestPhotoIdRepository = oldestPhotoIdRepository
    }

    func execute(with list: PhotosList) async throws -> PhotosLoadResponse {
        let shareId = try await shareIdDataSource.getShareId()
        try await updateLocalLinks(with: list, shareId: shareId)
        guard let lastPhoto = list.photos.last else {
            return PhotosLoadResponse(lastItem: nil)
        }

        let lastId = lastPhoto.linkID
        let localLastId = try? oldestPhotoIdRepository.getOldestPhotoId()
        let item = PhotosLoadResponse.Item(
            id: lastId,
            captureTime: Date(timeIntervalSince1970: TimeInterval(lastPhoto.captureTime)),
            isLastLocally: localLastId == lastId
        )
        return PhotosLoadResponse(lastItem: item)
    }

    private func updateLocalLinks(with list: PhotosList, shareId: String) async throws {
        let linkIds = list.photos.map { $0.linkID }
        let parameters = LinksMetadataParameters(shareId: shareId, linkIds: linkIds)
        let links = try await listing.getLinksMetadata(with: parameters).links
        try updateRepository.update(links: links, shareId: shareId)
    }
}
