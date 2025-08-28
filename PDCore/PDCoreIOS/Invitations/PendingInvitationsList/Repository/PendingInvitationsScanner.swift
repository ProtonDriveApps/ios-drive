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

import PDCore
import PDClient
import Foundation

protocol PendingInvitationsScannerProtocol {
    func scan() async throws
}

final class PendingInvitationsScanner: PendingInvitationsScannerProtocol {
    private let pendingInvitationIdsDataSource: PaginatedInvitationsIdentifiersListDataSourceProtocol
    private let invitationsMetadatasDataSource: InvitationsMetadatasDataSourceProtocol
    private let storageManager: StorageManager
    private let configuration: PendingInvitationsConfiguration

    init(pendingInvitationIdsDataSource: PaginatedInvitationsIdentifiersListDataSourceProtocol, invitationsMetadatasDataSource: InvitationsMetadatasDataSourceProtocol, storageManager: StorageManager, configuration: PendingInvitationsConfiguration) {
        self.pendingInvitationIdsDataSource = pendingInvitationIdsDataSource
        self.invitationsMetadatasDataSource = invitationsMetadatasDataSource
        self.storageManager = storageManager
        self.configuration = configuration
    }

    func scan() async throws {
        let pendingInvitations = try await fetchPendingInvitationIds()

        let localInvitationIds = await fetchLocalInvitationIds()

        // Identify outdated invitations
        let fetchedIdsSet = Set(pendingInvitations.map { $0.invitationId })
        let localIdsSet = Set(localInvitationIds)
        let outdatedIds = localIdsSet.subtracting(fetchedIdsSet)

        // Delete outdated invitations
        try await deleteOutdatedInvitations(with: Array(outdatedIds))

        for invitation in pendingInvitations {
            do {
                try await fetchAndCacheInvitationMetadata(invitation: invitation)
            } catch {
                Log.error("Failed scanning pending invitation scan invitation \(invitation.invitationId)", error: error, domain: .sharing)
            }
        }

        Log.info("Did finish scan pending invitations", domain: .sharing)
    }

    private func fetchPendingInvitationIds() async throws -> [InvitationIdentifier] {
        var invitations = [InvitationIdentifier]()
        var more = false
        var anchorId: String?

        repeat {
            let response = try await pendingInvitationIdsDataSource.getPaginatedInvitations(anchorID: anchorId, limit: nil, shareTypes: configuration.shareTypes)
            invitations += response.invitations.map { InvitationIdentifier(volumeId: $0.volumeID, shareID: $0.shareID, invitationId: $0.invitationID) }
            more = response.more
            anchorId = response.anchorID
        } while more

        return invitations
    }

    private func fetchAndCacheInvitationMetadata(invitation: InvitationIdentifier) async throws {
        let metadata = try await invitationsMetadatasDataSource.fetchInvitationMetadata(identifier: invitation)

        try await self.storageManager.backgroundContext.perform {
            let invitation = Invitation.fetchOrCreate(id: metadata.invitation.invitationID, in: self.storageManager.backgroundContext)
            invitation.populate(with: metadata)
            try self.storageManager.backgroundContext.saveOrRollback()
        }
    }

    private func fetchLocalInvitationIds() async -> [String] {
        await storageManager.backgroundContext.perform {
            self.storageManager.fetchInvitationIds(moc: self.storageManager.backgroundContext)
        }
    }

    private func deleteOutdatedInvitations(with ids: [String]) async throws {
        guard !ids.isEmpty else { return }

        try await storageManager.backgroundContext.perform {
            let outdatedInvitations = self.storageManager.fetchInvitations(with: ids, in: self.storageManager.backgroundContext)
            outdatedInvitations.forEach(self.storageManager.backgroundContext.delete)
            try self.storageManager.backgroundContext.saveOrRollback()
        }
    }
}

extension Invitation {
    public func populate(with metadata: ReturnInvitationInformationResponse) {
        // Populate fields from invitation metadata
        self.inviterEmail = metadata.invitation.inviterEmail
        self.inviteeEmail = metadata.invitation.inviteeEmail
        self.permissions = Int16(metadata.invitation.permissions)
        self.keyPacket = metadata.invitation.keyPacket
        self.keyPacketSignature = metadata.invitation.keyPacketSignature
        self.createTime = Date(timeIntervalSince1970: Double(metadata.invitation.createTime))

        // Populate fields from share metadata
        self.shareID = metadata.share.shareID
        self.volumeID = metadata.share.volumeID
        self.passphrase = metadata.share.passphrase
        self.shareKey = metadata.share.shareKey
        self.creatorEmail = metadata.share.creatorEmail

        // Populate fields from link metadata
        self.type = Int16(metadata.link.type)
        self.linkID = metadata.link.linkID
        self.name = metadata.link.name

        // Set MIME type with fallback logic
        if let mimeType = metadata.link.MIMEType {
            self.mimeType = mimeType
        } else if let linkType = LinkType(rawValue: metadata.link.type) {
            // BE will stop sending mimetype for folders and albums, so we need to use link type as the source of truth
            switch linkType {
            case .folder:
                self.mimeType = Folder.mimeType
            case .file:
                self.mimeType = MimeType.bin.value
            case .album:
                self.mimeType = CoreDataAlbum.mimeType
            }
        } else {
            self.mimeType = MimeType.bin.value
        }
    }
}
