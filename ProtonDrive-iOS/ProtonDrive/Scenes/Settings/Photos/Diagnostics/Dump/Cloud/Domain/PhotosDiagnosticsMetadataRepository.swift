// Copyright (c) 2024 Proton AG
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

struct PhotosDiagnosticsResponse {
    struct Photo {
        let primary: PDClient.Link
        let secondary: [PDClient.Link]
    }

    let share: PDClient.Share
    let root: PDClient.Link
    let photos: [Photo]
}

final class PhotosDiagnosticsMetadataRepository {
    private let shareListing: PhotoShareListing
    private let photosListing: PhotosListing

    init(shareListing: PhotoShareListing, photosListing: PhotosListing) {
        self.shareListing = shareListing
        self.photosListing = photosListing
    }

    func load() async throws -> PhotosDiagnosticsResponse {
        Log.debug("Loading photos root", domain: .diagnostics)
        let rootResponse = try await shareListing.getPhotosRoot()
        Log.debug("Loading photos ids", domain: .diagnostics)
        let listResponse = try await loadPhotoIds(rootResponse: rootResponse)
        Log.debug("Count of primary photos: \(listResponse.count)", domain: .diagnostics)
        let photos = try await listResponse.splitInGroups(of: 150).parallelMap { [unowned self] listResponse in
            try await self.loadPhotosMetadata(listResponse: listResponse, rootResponse: rootResponse)
        }.reduce([], +)
        return PhotosDiagnosticsResponse(share: rootResponse.share, root: rootResponse.link, photos: photos)
    }

    private func loadPhotoIds(lastId: String? = nil, rootResponse: PhotosRoot) async throws -> [PhotosListResponse.Photo] {
        // Fetch photos list
        let parameters = PhotosListRequestParameters(
            volumeId: rootResponse.share.volumeID,
            lastId: lastId,
            pageSize: 500
        )
        let listResponse = try await photosListing.getPhotosList(with: parameters)
        guard !listResponse.photos.isEmpty else {
            return []
        }
        return listResponse.photos + (try await loadPhotoIds(lastId: listResponse.photos.last?.linkID, rootResponse: rootResponse))
    }

    func loadPhotosMetadata(listResponse: [PhotosListResponse.Photo], rootResponse: PhotosRoot) async throws -> [PhotosDiagnosticsResponse.Photo] {
        Log.debug("Loading photos metadata", domain: .diagnostics)

        // Based on photos list fetch metadata of primary photos
        let shareId = rootResponse.share.shareID
        let linkIds = listResponse.map(\.linkID)
        let links = try await loadLinks(shareId: shareId, linkIds: linkIds)

        // Fill secondary photos metadata if necessary - metadata for related photos need to be fetched in a separate request
        let secondaryPhotos = try await loadSecondary(listResponse: listResponse, shareId: shareId)
        let photos = try links.map { primaryLink in
            // We try to be efficient with network requests (fetching in a batch), so the secondary links metadata need to be filtered later
            let relatedIds = try listResponse.first(where: { $0.linkID == primaryLink.linkID })?.relatedPhotos ?! "Inconsistent state, missing linkId"
            let secondaryLinks = secondaryPhotos.filter { secondaryLink in
                relatedIds.contains(where: { $0.linkID == secondaryLink.linkID })
            }
            return PhotosDiagnosticsResponse.Photo(primary: primaryLink, secondary: secondaryLinks)
        }

        return photos
    }

    private func loadLinks(shareId: String, linkIds: [String]) async throws -> [PDClient.Link] {
        return try await linkIds.splitInGroups(of: 150).parallelMap { [unowned self] linkIds in
            let parameters = LinksMetadataParameters(shareId: shareId, linkIds: linkIds)
            return try await photosListing.getLinksMetadata(with: parameters).links
        }.reduce([], +)
    }

    private func loadSecondary(listResponse: [PhotosListResponse.Photo], shareId: String) async throws -> [PDClient.Link] {
        let relatedLinkIds = listResponse.flatMap(\.relatedPhotos).map(\.linkID)
        guard !relatedLinkIds.isEmpty else {
            return []
        }
        return try await loadLinks(shareId: shareId, linkIds: relatedLinkIds)
    }
}
