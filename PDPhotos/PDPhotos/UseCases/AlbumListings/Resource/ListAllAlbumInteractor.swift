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

enum ListAlbumsInput {
    case all
    case own
    case sharedWithMe
}

protocol ListAllAlbumInteractorProtocol {
    func execute(input: ListAlbumsInput) async throws -> [RemoteAlbumListing]
}

/// List all of albums from scratch
struct ListAllAlbumInteractor: ListAllAlbumInteractorProtocol {
    private let listOwnedAlbumInteractor: ListRemoteAlbumInteractorProtocol
    private let listSharedWithMeAlbumInteractor: ListRemoteAlbumInteractorProtocol

    init(
        listOwnedAlbumInteractor: ListRemoteAlbumInteractorProtocol,
        listSharedWithMeAlbumInteractor: ListRemoteAlbumInteractorProtocol
    ) {
        self.listOwnedAlbumInteractor = listOwnedAlbumInteractor
        self.listSharedWithMeAlbumInteractor = listSharedWithMeAlbumInteractor
    }

    func execute(input: ListAlbumsInput) async throws -> [RemoteAlbumListing] {
        switch input {
        case .all:
            async let ownedAlbums = listOwnedAlbumInteractor.execute()
            async let sharedWithMeAlbum = listSharedWithMeAlbumInteractor.execute()
            let albums = try await [ownedAlbums, sharedWithMeAlbum].flatMap { $0 }
            return sortedAlbums(from: albums)
        case .own:
            return try await listOwnedAlbumInteractor.execute()
        case .sharedWithMe:
            return try await listSharedWithMeAlbumInteractor.execute()
        }
    }

    private func sortedAlbums(from albums: [RemoteAlbumListing]) -> [RemoteAlbumListing] {
        albums.sorted(by: { $0.lastActivityTime > $1.lastActivityTime })
    }
}
