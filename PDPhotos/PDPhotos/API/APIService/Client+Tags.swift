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

import Foundation
import PDClient

public protocol PhotoTagClient {
    func assignTagsToPhoto(parameters: AssignTagToPhotoRequest.Parameters) async throws
    func removeTagsFromPhoto(parameters: AssignTagToPhotoRequest.Parameters) async throws
    func favoritePhoto(parameters: FavoritingPhotosParameters) async throws -> FavoritingPhotosResponse
}

extension Client: PhotoTagClient {
    public func assignTagsToPhoto(parameters: AssignTagToPhotoRequest.Parameters) async throws {
        if parameters.body.tags.isEmpty { return }
        let credential = try credential()
        let endpoint = try AssignTagToPhotoRequest(parameters: parameters, service: service, credential: credential)
        _ = try await request(endpoint)
    }

    public func removeTagsFromPhoto(parameters: AssignTagToPhotoRequest.Parameters) async throws {
        if parameters.body.tags.isEmpty { return }
        let credential = try credential()
        let endpoint = try RemoveTagFromPhotoRequest(parameters: parameters, service: service, credential: credential)
        _ = try await request(endpoint)
    }

    public func favoritePhoto(parameters: FavoritingPhotosParameters) async throws -> FavoritingPhotosResponse {
        let credential = try credential()
        let endpoint = try FavoritingPhotosRequest(parameters: parameters, service: service, credential: credential)
        return try await request(endpoint)
    }
}
