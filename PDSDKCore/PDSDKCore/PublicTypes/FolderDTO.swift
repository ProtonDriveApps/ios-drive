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

import Foundation
import PDCore
import ProtonDriveSDK

public struct FolderDTO: Sendable {
    public let sdkFolderNode: SDKFolderNode
    public let local: NodeLocalDTO
    public let isRoot: Bool
    public let isChildrenListFullyFetched: Bool

    init(folder: CoreDataFolder, signatureKeys: [PublicKey]) throws {
        let name: Result<String, ProtonDriveSDKDriveError>
        do {
            let decryptedName = try folder.decryptName(signatureKeys: signatureKeys)
            name = .success(decryptedName)
        } catch {
            name = .failure(.init(message: error.localizedDescription))
        }
        // TODO: finder-refactor, review highlight owner == creatorEmail ?
        let creatorEmail = folder.directShares.first?.members.first?.inviter ?? ""

        let shareURLIsEmpty = try folder.getContextShare().shareUrls.isEmpty

        self.sdkFolderNode = SDKFolderNode(
            uid: folder.genericIdentifier.sdkUid,
            parentUid: folder.parentFolder?.genericIdentifierWithinManagedObjectContext.sdkUid,
            name: name,
            creationTime: folder.createdDate.timeIntervalSince1970,
            trashTime: nil,
            nameAuthor: SDKAuthor(emailAddress: folder.nameSignatureEmail, signatureVerificationError: nil),
            keyAuthor: SDKAuthor(emailAddress: folder.signatureEmail, signatureVerificationError: nil),
            ownedBy: SDKOwnedBy(email: creatorEmail, organization: nil),
            isShared: folder.isShared,
            isSharedByUrl: !shareURLIsEmpty,
            errors: []
        )
        self.local = NodeLocalDTO(node: folder)
        self.isRoot = folder.isRoot
        self.isChildrenListFullyFetched = folder.isChildrenListFullyFetched
    }
}

// MARK: - Folder only conveniences (false for files)
public extension NodeDTO {
    var isFolder: Bool {
        switch self {
        case .file: return false
        case .folder: return true
        }
    }

    var isRoot: Bool {
        switch self {
        case .file: return false
        case .folder(let folder): return folder.isRoot
        }
    }

    var isChildrenListFullyFetched: Bool {
        switch self {
        case .file: return false
        case .folder(let folder): return folder.isChildrenListFullyFetched
        }
    }
}
