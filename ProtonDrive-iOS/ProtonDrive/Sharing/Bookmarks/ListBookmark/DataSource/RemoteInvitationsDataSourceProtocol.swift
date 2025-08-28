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

extension Client: BookmarksRemoteDataSource {
    func getBookmarks() async throws -> [Bookmark] {
        let endpoint = ListBookmarksEndpoint(service: service, credential: try credential())
        return try await request(endpoint, completionExecutor: .immediateExecutor).bookmarks.map(\.asDomainBookmark)
    }
}

extension ListBookmarksResponse.BookmarkResponse {
    var asDomainBookmark: Bookmark {
        return Bookmark(
            encryptedUrlPassword: self.encryptedUrlPassword,
            createTime: Date(timeIntervalSince1970: TimeInterval(self.createTime)),
            token: self.token.mapToDomainModel()
        )
    }
}

extension ListBookmarksResponse.BookmarkResponse.TokenResponse {
    func mapToDomainModel() -> Bookmark.Token {
        let mimeType = linkType == 1 ? Folder.mimeType : (self.MIMEType ?? MimeType.bin.value)
        return Bookmark.Token(
            token: self.token,
            linkType: self.linkType,
            linkID: self.linkID,
            sharePasswordSalt: self.sharePasswordSalt,
            sharePassphrase: self.sharePassphrase,
            shareKey: self.shareKey,
            nodePassphrase: self.nodePassphrase,
            nodeKey: self.nodeKey,
            name: self.name,
            contentKeyPacket: self.contentKeyPacket ?? "",
            mimeType: mimeType,
            permissions: self.permissions,
            size: self.size ?? 0,
            thumbnailURLInfo: self.thumbnailURLInfo?.mapToDomainModel(),
            nodeHashKey: self.nodeHashKey
        )
    }
}

extension ListBookmarksResponse.BookmarkResponse.TokenResponse.ThumbnailURLInfoResponse {
    func mapToDomainModel() -> Bookmark.Token.ThumbnailURLInfo {
        return Bookmark.Token.ThumbnailURLInfo(
            url: self.url ?? "",
            bareURL: self.bareURL ?? "",
            token: self.token ?? ""
        )
    }
}
