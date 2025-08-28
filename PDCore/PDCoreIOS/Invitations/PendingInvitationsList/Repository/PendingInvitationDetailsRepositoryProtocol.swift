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

import CoreData
import PDCore

struct PendingInvitation {
    let id: String
    let name: String
    let inviterEmail: String
    let mimeType: String
    let invitationDate: Date
}

protocol PendingInvitationDetailsRepositoryProtocol {
    func getPendingInvitation(_ id: String) async -> PendingInvitation
    func acceptPendingInvitation(_ id: String) async throws
    func rejectPendingInvitation(_ id: String) async throws
}

final class PendingInvitationDetailsRepository: PendingInvitationDetailsRepositoryProtocol {
    private let storage: StorageManager
    private let context: NSManagedObjectContext
    private let rejectionDataSource: InvitationRejectionDataSource
    private let acceptanceDataSource: InvitationAcceptanceDataSource

    init(storage: StorageManager, acceptanceDataSource: InvitationAcceptanceDataSource, rejectionDataSource: InvitationRejectionDataSource) {
        self.storage = storage
        self.context = storage.backgroundContext
        self.acceptanceDataSource = acceptanceDataSource
        self.rejectionDataSource = rejectionDataSource
    }

    func getPendingInvitation(_ id: String) async -> PendingInvitation {
        await context.perform {
            do {
                let invitation = try self.storage.getInvitation(id: id, in: self.context)
                let decryptedName = try invitation.decryptedInvitationName()
                let pendingInvitation = PendingInvitation(id: id, name: decryptedName, inviterEmail: invitation.inviterEmail, mimeType: invitation.mimeType, invitationDate: invitation.createTime)
                return pendingInvitation
            } catch {
                return PendingInvitation(id: id, name: "�", inviterEmail: "", mimeType: "", invitationDate: .distantPast)
            }
        }
    }

    func acceptPendingInvitation(_ id: String) async throws {
        let signature = try await context.perform {
            let invitation = try self.storage.getInvitation(id: id, in: self.context)
            let signature = try invitation.signedSessionKey()
            return signature
        }
        try await acceptanceDataSource.acceptInvitation(id: id, signature: signature)
        try await finishInvitation(id)
    }

    func rejectPendingInvitation(_ id: String) async throws {
        try await rejectionDataSource.rejectInvitation(invitationId: id)
        try await finishInvitation(id)
    }

    private func finishInvitation(_ id: String) async throws {
        try await context.perform {
            let invitation = try self.storage.getInvitation(id: id, in: self.context)
            self.context.delete(invitation)
            try self.context.saveOrRollback()
        }
    }
}
