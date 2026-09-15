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

import PDClient
import PDCore

/// Encapsulates the sharing-management rules for a node.
///
/// The `Node` is treated as a plain data source (its role and permissions);
/// the policy decisions live here rather than on the domain object.
///
/// - Important: The `init(node:...)` variant reads the node's CoreData relationships
///   (`getNodeRole()`/`getNodePermissions()`) and direct share `editorsCanShare` eagerly, so it must be created on the
///   node's managed-object-context queue — in practice the main thread, as all call
///   sites are SwiftUI view models operating on view-context nodes.
public struct NodeSharingPolicy {
    private let role: Role
    private let permissions: Permissions
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let shareAllowsEditorManagement: Bool

    public init(node: Node, featureFlagsController: FeatureFlagsControllerProtocol) {
        guard let managedObjectContext = try? node.getManagedObjectContext() else {
            // There can be a race condition and the node can be already deleted. In that case, return minimal role/permissions.
            // In next UI redraw this gets autocorrected
            self = NodeSharingPolicy(
                role: .viewer,
                permissions: .view,
                featureFlagsController: featureFlagsController,
                shareAllowsEditorManagement: false
            )
            return
        }

        let (role, permissions, editorsCanShare) = managedObjectContext.performAndWait { () -> (Role, Permissions, Bool) in
            (
                node.getNodeRole(),
                node.getNodePermissions(),
                node.getStandardShare()?.editorsCanShare ?? false
            )
        }
        self.init(
            role: role,
            permissions: permissions,
            featureFlagsController: featureFlagsController,
            shareAllowsEditorManagement: editorsCanShare
        )
    }

    public init(
        role: Role,
        permissions: Permissions,
        featureFlagsController: FeatureFlagsControllerProtocol,
        shareAllowsEditorManagement: Bool = false
    ) {
        self.role = role
        self.permissions = permissions
        self.featureFlagsController = featureFlagsController
        self.shareAllowsEditorManagement = shareAllowsEditorManagement
    }

    /// Whether the current user owns the item. Owner-only capabilities (e.g. managing the public
    /// share link) gate on this rather than `canManageSharing()`, which also allows admins.
    public var isOwner: Bool {
        role == .owner
    }

    /// Whether the current user can open sharing management (invite, remove members, change permissions).
    /// - Parameter editorsCanShare: When set, overrides the value captured at initialization (e.g. live share metadata in the sharing UI).
    public func canManageSharing(editorsCanShare: Bool? = nil) -> Bool {
        let shareAllowsEditorManagement = editorsCanShare ?? shareAllowsEditorManagement
        switch role {
        case .owner:
            return true
        case .admin:
            return featureFlagsController.hasSharingAdminPermissions
        case .editor:
            return shareAllowsEditorManagement
        case .viewer:
            return false
        }
    }

    /// Maximum permissions the current user may grant when inviting or updating members.
    public func getInviterPermissions() -> AccessPermission {
        switch permissions {
        case .view:
            return [.read]
        case .edit:
            return [.read, .write]
        case .administrate:
            return [.read, .write, .admin]
        }
    }
}
