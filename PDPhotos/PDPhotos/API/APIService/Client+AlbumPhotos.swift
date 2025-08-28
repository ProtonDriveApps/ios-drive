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

protocol AlbumPhotosAPIService {
    func removePhotosFromAlbum(
        volumeID: String,
        linkID: String,
        photoLinkIDs: [String]
    ) async throws -> RemovePhotosFromAlbumResponse
    func addExistingPhotosToAlbum(
        volumeID: String,
        linkID: String,
        body: AddExistingPhotosToAlbumRequest.Body
    ) async throws -> AddExistingPhotosToAlbumResponse
}

protocol RemotePhotosListingRepository: PhotosListing {
    func listPhotosInAlbum(parameters: ListPhotosInAlbumRequest.Parameters) async throws -> ListPhotosInAlbumResponse
}

extension Client: AlbumPhotosAPIService, RemotePhotosListingRepository {
    func removePhotosFromAlbum(
        volumeID: String,
        linkID: String,
        photoLinkIDs: [String]
    ) async throws -> RemovePhotosFromAlbumResponse {
        let credential = try credential()
        let endpoint = try RemovePhotosFromAlbumRequest(
            volumeID: volumeID,
            linkID: linkID,
            photoLinkIDs: photoLinkIDs,
            service: service,
            credential: credential
        )
        let response = try await request(endpoint)
        return response
    }

    func listPhotosInAlbum(
        parameters: ListPhotosInAlbumRequest.Parameters
    ) async throws -> ListPhotosInAlbumResponse {
        let credential = try credential()
        let endpoint = try ListPhotosInAlbumRequest(parameters: parameters, service: service, credential: credential)
        return try await request(endpoint)
    }

    func addExistingPhotosToAlbum(
        volumeID: String,
        linkID: String,
        body: AddExistingPhotosToAlbumRequest.Body
    ) async throws -> AddExistingPhotosToAlbumResponse {
        let credential = try credential()
        let endpoint = try AddExistingPhotosToAlbumRequest(
            volumeID: volumeID,
            linkID: linkID,
            body: body,
            service: service,
            credential: credential
        )
        return try await request(endpoint)
    }
}
