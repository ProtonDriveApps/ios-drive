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
import CoreData

struct ShareCreator {
    public typealias CloudShareCreator = (Client.VolumeID, NewShareParameters) async throws -> NewShareShort

    private let moc: NSManagedObjectContext
    private let storage: StorageManager
    private let sessionVault: SessionVault
    private let signersKitFactory: SignersKitFactoryProtocol
    private let cloudShareCreator: CloudShareCreator

    public init(
        storage: StorageManager,
        sessionVault: SessionVault,
        cloudShareCreator: @escaping CloudShareCreator,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.moc = moc
        self.storage = storage
        self.sessionVault = sessionVault
        self.signersKitFactory = sessionVault
        self.cloudShareCreator = cloudShareCreator
    }

    public func create(for root: Node) async throws -> Share {
        let shareName = "New share"

        let (volumeID, rootLinkID, rootKey, mainShareCreator, volume) = try await moc.perform {
            let root = root.in(moc: self.moc)

            guard let mainShare = storage.mainShareOfVolume(by: sessionVault.addressIDs, moc: self.moc) else {
                throw Share.InvalidState(message: "No main share found in volume.")
            }

            guard let volume = mainShare.volume else {
                throw Volume.InvalidState(message: "No volume found while trying to create a collaborative share.")
            }

            guard let mainShareCreator = mainShare.creator else {
                throw Share.InvalidState(message: "No creator found in main share.")
            }

            return (volume.id, root.id, root.nodeKey, mainShareCreator, volume)
        }

        let signersKit = try sessionVault.make(forSigner: .address(mainShareCreator))

        let shareKeys = try Encryptor.generateNodeKeys(addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey, parentKey: signersKit.addressKey.privateKey)

        let (passphraseKeyPacket, nameKeyPacket) = try await moc.perform {
            let root = root.in(moc: self.moc)

            guard let rootName = root.name else {
                throw root.invalidState("The Node has no name.")
            }

            let passphraseKeyPacket = try root.keyPacket(root.nodePassphrase, newKey: shareKeys.key)
            let nameKeyPacket = try root.keyPacket(rootName, newKey: shareKeys.key)

            return (passphraseKeyPacket, nameKeyPacket)
        }

        let newSharePassphrase = try Encryptor.encryptPGPMessageToAdditionalKey(shareKeys.passphrase, oldEncryptingKey: signersKit.addressKey.privateKey, oldEncryptingKeyPassphrase: signersKit.addressPassphrase, newEncryptingKey: rootKey)

        let parameters = NewShareParameters(
            addressID: signersKit.address.addressID,
            name: shareName,
            rootLinkID: rootLinkID,
            shareKey: shareKeys.key,
            sharePassphrase: newSharePassphrase,
            sharePassphraseSignature: shareKeys.signature,
            passphraseKeyPacket: passphraseKeyPacket,
            nameKeyPacket: nameKeyPacket
        )

        let shareID = try await cloudShareCreator(volumeID, parameters).ID

        return try await moc.perform {
            let root = root.in(moc: self.moc)
            let share: Share = self.storage.new(with: shareID, by: #keyPath(Share.id), in: moc)
            share.addressID = signersKit.address.addressID
            share.creator = mainShareCreator
            share.key = shareKeys.key
            share.passphrase = newSharePassphrase
            share.passphraseSignature = shareKeys.signature
            share.type = .standard

            share.volume = volume
            share.root = root
            root.directShares.insert(share)

            try self.moc.saveOrRollback()
            Log.info("New share was created with id: \(shareID), root: \(root.identifier)", domain: .storage)

            return share
        }
    }
}
