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

public struct Bookmark: Equatable {
    public let encryptedUrlPassword: String
    public let createTime: Date
    public let token: Token

    public init(encryptedUrlPassword: String, createTime: Date, token: Token) {
        self.encryptedUrlPassword = encryptedUrlPassword
        self.createTime = createTime
        self.token = token
    }

    public struct Token: Equatable {
        public let token: String
        public let linkType: Int
        public let linkID: String
        public let sharePasswordSalt: String
        public let sharePassphrase: String
        public let shareKey: String
        public let nodePassphrase: String
        public let nodeKey: String
        public let name: String
        public let contentKeyPacket: String
        public let mimeType: String
        public let permissions: Int
        public let size: Int
        public let thumbnailURLInfo: ThumbnailURLInfo?
        public let nodeHashKey: String?

        public init(token: String, linkType: Int, linkID: String, sharePasswordSalt: String, sharePassphrase: String, shareKey: String, nodePassphrase: String, nodeKey: String, name: String, contentKeyPacket: String, mimeType: String, permissions: Int, size: Int, thumbnailURLInfo: ThumbnailURLInfo?, nodeHashKey: String?) {
            self.token = token
            self.linkType = linkType
            self.linkID = linkID
            self.sharePasswordSalt = sharePasswordSalt
            self.sharePassphrase = sharePassphrase
            self.shareKey = shareKey
            self.nodePassphrase = nodePassphrase
            self.nodeKey = nodeKey
            self.name = name
            self.contentKeyPacket = contentKeyPacket
            self.mimeType = mimeType
            self.permissions = permissions
            self.size = size
            self.thumbnailURLInfo = thumbnailURLInfo
            self.nodeHashKey = nodeHashKey
        }

        public struct ThumbnailURLInfo: Equatable {
            public let url: String
            public let bareURL: String
            public let token: String

            public init(url: String, bareURL: String, token: String) {
                self.url = url
                self.bareURL = bareURL
                self.token = token
            }
        }
    }
}
