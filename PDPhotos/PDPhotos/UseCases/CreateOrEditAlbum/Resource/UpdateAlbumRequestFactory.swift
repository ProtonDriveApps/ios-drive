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

import CoreData
import PDCore

protocol UpdateAlbumRequestFactoryProtocol {
    func makeRequestLink(parameters: UpdateAlbumParameters) async throws -> UpdateAlbumRequest.Link?
}

final class UpdateAlbumRequestFactory: UpdateAlbumRequestFactoryProtocol {
    private let managedObjectContext: NSManagedObjectContext
    private let encryptionResource: EncryptionResource
    private let signersKitFactory: SignersKitFactoryProtocol

    init(managedObjectContext: NSManagedObjectContext, encryptionResource: EncryptionResource, signersKitFactory: SignersKitFactoryProtocol) {
        self.managedObjectContext = managedObjectContext
        self.encryptionResource = encryptionResource
        self.signersKitFactory = signersKitFactory
    }

    func makeRequestLink(parameters: UpdateAlbumParameters) async throws -> UpdateAlbumRequest.Link? {
        guard let newName = validatedName(from: parameters.newAlbumName) else {
            return nil
        }

        let (album, oldNodeName, parentKey, parentPassphrase, parentHashKey, signersKit, nodeHash) = try await managedObjectContext.perform {
            let album: CoreDataAlbum = try CoreDataAlbum.fetchOrThrow(identifier: parameters.albumID, in: self.managedObjectContext)

            let addressID = try album.getContextShareAddressID()
            let signersKit = try self.signersKitFactory.make(forAddressID: addressID)

            guard let oldNodeName = album.name else { throw album.invalidState("The renaming Node should have a valid old name.") }
            guard let parent = album.parentNode else { throw album.invalidState("The renaming Node should have a parent.") }

            let parentKey = parent.nodeKey
            let parentPassphrase = try parent.decryptPassphrase()
            let parentHashKey = try parent.decryptNodeHashKey()

            return (album, oldNodeName, parentKey, parentPassphrase, parentHashKey, signersKit, album.nodeHash)
        }
        let newEncryptedName = try album.renameNode(
            oldEncryptedName: oldNodeName,
            oldParentKey: parentKey,
            oldParentPassphrase: parentPassphrase,
            newClearName: newName,
            newParentKey: parentKey,
            signersKit: signersKit
        )
        let newNameHash = try encryptionResource.makeHmac(string: newName, hashKey: parentHashKey)
        let albumNodeHash = try nodeHash ?! "Nil album node hash"

        return UpdateAlbumRequest.Link(
            name: newEncryptedName,
            hash: newNameHash,
            nameSignatureEmail: signersKit.address.email,
            originalHash: albumNodeHash,
            xAttr: nil
        )
    }

    private func validatedName(from name: String?) -> String? {
        let clearName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clearName.isEmpty ? nil : clearName
    }
}
