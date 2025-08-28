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

import PDClient

protocol AlbumAPIService {
    func createAlbum(volumeID: String, parameter: CreateAlbumRequest.Parameters) async throws -> PDClient.Link.LinkID
    func updateAlbum(parameter: UpdateAlbumRequest.Parameters) async throws
    func deleteAlbum(parameters: DeleteAlbumRequest.Parameters) async throws
}

extension Client: AlbumAPIService {

    func createAlbum(volumeID: String, parameter: CreateAlbumRequest.Parameters) async throws -> PDClient.Link.LinkID {
        let credential = try credential()
        let endpoint = try CreateAlbumRequest(
            volumeID: volumeID,
            parameter: parameter,
            service: service,
            credential: credential
        )
        do {
            let response = try await request(endpoint)
            guard let linkID = response.album?.link.linkID else {
                throw CreateAlbumError.emptyLinkID
            }
            return linkID
        } catch {
            //        // TODO:album, move response.code to interactor
            //        if httpResponse.statusCode == 422 {
            //            // There will be a limit of 500 Albums per Volume, BE will reply with HTTP 422 body 200_300 if the limit get exceeded
            //            // TODO:album Check what is the exactly response
            //            throw CreateAlbumError.exceedMaxAlbums
            //        }
            throw error
        }
    }
    
    func updateAlbum(parameter: UpdateAlbumRequest.Parameters) async throws {
        let credential = try credential()
        let endpoint = try UpdateAlbumRequest(parameters: parameter, service: service, credential: credential)
        _ = try await request(endpoint)
    }

    func deleteAlbum(parameters: DeleteAlbumRequest.Parameters) async throws {
        let credential = try credential()
        let endpoint = try DeleteAlbumRequest(parameters: parameters, service: service, credential: credential)
        _ = try await request(endpoint)
    }
}
