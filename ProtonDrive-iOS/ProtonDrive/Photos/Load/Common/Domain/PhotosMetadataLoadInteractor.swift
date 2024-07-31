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

    init(shareIdDataSource: PhotoShareIdDataSource, listing: PhotosListing, updateRepository: LinksUpdateRepository) {
        self.shareIdDataSource = shareIdDataSource
        self.listing = listing
        self.updateRepository = updateRepository
    }

    func execute(with list: PhotosList) async throws -> PhotosLoadResponse {
        let shareId = try await shareIdDataSource.getShareId()
        try await updateLocalLinks(with: list, shareId: shareId)
        guard let lastPhoto = list.photos.last else {
            return PhotosLoadResponse(lastItem: nil, captureTimeThreshold: nil)
        }

        let lastId = lastPhoto.linkID
        let item = PhotosLoadResponse.Item(
            id: lastId,
            captureTime: Date(timeIntervalSince1970: TimeInterval(lastPhoto.captureTime))
        )
        
        let fetchBar = 70
        let startIdx = list.photos.count - fetchBar
        let time = startIdx <= 0 ? nil : Date(timeIntervalSince1970: TimeInterval(list.photos[startIdx].captureTime))

        return PhotosLoadResponse(lastItem: item, captureTimeThreshold: time)
    }

    private func updateLocalLinks(with list: PhotosList, shareId: String) async throws {
        let linkIds = list.photos.flatMap { [$0.linkID] + $0.relatedPhotos.map(\.linkID) }
        let chunks = linkIds.splitInGroups(of: 150)
        var allLinks: [Link] = []
        for chunk in chunks {
            let parameters = LinksMetadataParameters(shareId: shareId, linkIds: chunk)
            let links = try await listing.getLinksMetadata(with: parameters).links
            allLinks.append(contentsOf: links)
        }
        
        try updateRepository.update(links: allLinks, shareId: shareId)
    }
}
