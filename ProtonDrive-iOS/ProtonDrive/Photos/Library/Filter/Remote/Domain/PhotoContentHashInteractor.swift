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
import PDCore

protocol PhotoContentHashInteractor {
    func makeContentHash(from url: URL) throws -> String
}

final class LocalPhotoContentHashInteractor: PhotoContentHashInteractor {
    private let hashResource: FileHashResource
    private let rootDataSource: PhotosRootEncryptingFolderDataSource
    private let encryptionResource: EncryptionResource

    init(hashResource: FileHashResource, rootDataSource: PhotosRootEncryptingFolderDataSource, encryptionResource: EncryptionResource) {
        self.hashResource = hashResource
        self.rootDataSource = rootDataSource
        self.encryptionResource = encryptionResource
    }

    func makeContentHash(from url: URL) throws -> String {
        let sha1 = try hashResource.getHash(at: url)
        let root = try rootDataSource.getEncryptingFolder()
        let sha1HexString = sha1.hexString()
        return try encryptionResource.makeHmac(string: sha1HexString, hashKey: root.hashKey)
    }
}
