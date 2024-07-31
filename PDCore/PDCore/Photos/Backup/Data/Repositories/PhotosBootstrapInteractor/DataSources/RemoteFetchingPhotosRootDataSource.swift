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

import PDClient
import Foundation

public final class RemoteFetchingPhotosRootDataSource: PhotosShareDataSource {

    private let storage: StorageManager
    private let photoShareListing: PhotoShareListing

    public init(storage: StorageManager, photoShareListing: PhotoShareListing) {
        self.storage = storage
        self.photoShareListing = photoShareListing
    }

    public func getPhotoShare() async throws -> Share {
        let moc = storage.newBackgroundContext()

        guard let volume = storage.volumes(moc: moc).first else {
            throw Volume.InvalidState(message: "No volume found while trying to create photos share.")
        }

        let response = try await photoShareListing.getPhotosRoot()

        return try await moc.perform {
            let share: Share = self.storage.unique(with: [response.share.shareID], in: moc)[0]
            share.addressID = response.share.addressID
            share.creator = response.share.creator
            share.key = response.share.key
            share.passphrase = response.share.passphrase
            share.passphraseSignature = response.share.passphraseSignature
            share.type = .photos

            let root: Folder = self.storage.unique(with: [response.link.linkID], in: moc)[0]
            root.shareID = response.share.shareID
            root.nodeKey = response.link.nodeKey
            root.nodePassphrase = response.link.nodePassphrase
            root.nodePassphraseSignature = response.link.nodePassphraseSignature
            root.signatureEmail = response.link.signatureEmail
            root.name = response.link.name
            root.nameSignatureEmail = response.link.nameSignatureEmail
            root.nodeHashKey = response.link.folderProperties?.nodeHashKey
            root.nodeHash = response.link.hash
            root.mimeType = response.link.MIMEType
            root.createdDate = Date(timeIntervalSince1970: response.link.createTime)
            root.modifiedDate = Date(timeIntervalSince1970: response.link.modifyTime)

            share.volume = volume
            share.root = root

            try moc.saveOrRollback()

            return share
        }

    }
}
