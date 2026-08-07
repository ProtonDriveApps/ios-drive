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
import PDCore

struct LinkOwner {
    let email: String
    let isCurrentUser: Bool
}

/// Resolves the identity/ownership information the member-list UI needs, so the view model does not
/// depend directly on the managed-object graph or the `SessionVault`. This keeps the view model
/// unit-testable with a lightweight mock (the concrete resource touches CoreData and the keychain).
protocol SharingIdentityResource {
    /// The item owner to show at the top of the member list, or `nil` if it can't be resolved.
    func loadOwner() -> LinkOwner?
    /// The current user represented as an owner (their primary address), or `nil` if unavailable.
    /// Used as a fallback when the link's `OwnedBy` isn't populated yet but the caller already knows the
    /// current user owns the item.
    func loadCurrentUserAsOwner() -> LinkOwner?
    /// Whether the given email belongs to the current user (one of their addresses).
    func isCurrentUser(email: String) -> Bool
    /// The current user's display name, used for the "(you)" row.
    var currentUserName: String? { get }
}

final class NodeSharingIdentityResource: SharingIdentityResource {
    private let node: Node
    private let sessionVault: SessionVault

    init(node: Node, sessionVault: SessionVault) {
        self.node = node
        self.sessionVault = sessionVault
    }

    func loadOwner() -> LinkOwner? {
        guard let context = node.managedObjectContext else { return nil }
        let identity: String? = context.performAndWait {
            if let ownerEmail = node.ownerEmail, !ownerEmail.isEmpty {
                return ownerEmail
            }
            if let ownerOrganization = node.ownerOrganization, !ownerOrganization.isEmpty {
                return ownerOrganization
            }
            return nil
        }
        guard let identity, !identity.isEmpty else { return nil }
        return LinkOwner(email: identity, isCurrentUser: isCurrentUser(email: identity))
    }

    func loadCurrentUserAsOwner() -> LinkOwner? {
        guard let email = sessionVault.currentCreator(), !email.isEmpty else { return nil }
        return LinkOwner(email: email, isCurrentUser: true)
    }

    func isCurrentUser(email: String) -> Bool {
        sessionVault.getAddress(for: email) != nil
    }

    var currentUserName: String? {
        sessionVault.userInfo?.name
    }
}
