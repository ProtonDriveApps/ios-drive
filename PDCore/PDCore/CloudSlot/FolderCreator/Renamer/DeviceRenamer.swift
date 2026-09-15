// Copyright (c) 2026 Proton AG
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
import PDClient

public final class DeviceRenamer: NodeRenamerProtocol {
    /// Typealias for one of the methods of PDClient's Client.
    public typealias CloudNodeRenamer = (Client.ShareID, Client.LinkID, RenameNodeParameters) async throws -> Void

    private let storage: StorageManager
    private let signersKitFactory: SignersKitFactoryProtocol
    private let cloudNodeRenamer: CloudNodeRenamer
    private let nodeOperationPerformer: SDKNodeOperationPerformer?
    private let featureFlags: DriveFeatureFlagsProvider

    public init(
        storage: StorageManager,
        cloudNodeRenamer: @escaping CloudNodeRenamer,
        signersKitFactory: SignersKitFactoryProtocol,
        nodeOperationPerformer: SDKNodeOperationPerformer?,
        featureFlags: DriveFeatureFlagsProvider
    ) {
        self.storage = storage
        self.signersKitFactory = signersKitFactory
        self.cloudNodeRenamer = cloudNodeRenamer
        self.nodeOperationPerformer = nodeOperationPerformer
        self.featureFlags = featureFlags
    }

    public func rename(_ node: Node, to newName: String, mimeType: String?, moc: NSManagedObjectContext) async throws {
        if nodeOperationPerformer != nil, featureFlags.isEnabled(flag: .driveiOSSDKDevicesOperations) {
            try await sdkRename(node, to: newName, moc: moc)
        } else {
            try await legacyRename(node, to: newName, mimeType: mimeType, moc: moc)
        }
    }

    private func legacyRename(_ node: Node, to newName: String, mimeType: String?, moc: NSManagedObjectContext) async throws {
        let validatedNewName = try newName.validateNodeName(validator: NameValidations.iosName)

        let (nodeID, shareID, oldNodeName, shareKey, parentPassphrase, signersKit) = try await moc.perform {
            let node = node.in(moc: moc)
            let nodeID = node.id
            let contextShare = try node.getContextShare()
            let shareID = contextShare.id
            let addressID = try contextShare.getAddressID()
            let signersKit = try self.signersKitFactory.make(forAddressID: addressID)
            guard let oldNodeName = node.name else { throw node.invalidState("The renaming Node should have a valid old name.") }
            guard let share = node.primaryDirectShare else { throw node.invalidState("Device Root should have a Share") }
            guard let shareKey = share.key else { throw share.invalidState("Device share should be bootstrapped") }
            guard share.device != nil else { throw node.invalidState("Renaming roots is only valid for Devices") }
            let parentPassphrase = try share.decryptPassphrase()

            return (nodeID, shareID, oldNodeName, shareKey, parentPassphrase, signersKit)
        }

        let newEncryptedName = try node.renameNode(
            oldEncryptedName: oldNodeName,
            oldParentKey: shareKey,
            oldParentPassphrase: parentPassphrase,
            newClearName: validatedNewName,
            newParentKey: shareKey,
            signersKit: signersKit
        )

        let parameters = RenameNodeParameters(
            name: newEncryptedName,
            hash: nil,
            MIMEType: nil,
            signatureAddress: signersKit.address.email
        )

        try await cloudNodeRenamer(shareID, nodeID, parameters)

        try await moc.perform {
            let node = node.in(moc: moc)
            node.name = newEncryptedName
            node.nameSignatureEmail = signersKit.address.email

            try moc.saveOrRollback()
        }
    }

    private func sdkRename(_ node: CoreDataNode, to newName: String, moc: NSManagedObjectContext) async throws {
        let validatedNewName = try newName.validateNodeName(validator: NameValidations.iosName)
        let objectID = node.objectID
        let deviceIdentifier = try await moc.perform { [moc] in
            let node: CoreDataNode = try moc.typedObject(with: objectID)
            let contextShare = try node.getContextShare()
            guard let device = contextShare.device else {
                throw CoreDataShare.InvalidState(message: "Renaming roots is only valid for Devices")
            }
            return DeviceIdentifier(id: device.id, nodeID: node.id, shareID: contextShare.id, volumeID: device.volume.id)
        }
        try await nodeOperationPerformer?.renameDevice(identifier: deviceIdentifier, newName: validatedNewName)
    }
}
