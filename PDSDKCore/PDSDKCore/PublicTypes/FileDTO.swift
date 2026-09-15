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

public struct FileDTO: Sendable {
    public let sdkFileNode: SDKFileNode
    public let local: NodeLocalDTO

    // File-only UX flags the SDK does not yet model.
    public let canExport: Bool
    public let isBookmark: Bool
    public let isPhoto: Bool
    public let isLocalFile: Bool
    public let isProtonFile: Bool
    public let uploadID: UUID?

    init(file: CoreDataFile, signatureKeys: [PublicKey]) throws {
        let name: Result<String, ProtonDriveSDKDriveError>
        do {
            let decryptedName = try file.decryptName(signatureKeys: signatureKeys)
            name = .success(decryptedName)
        } catch {
            name = .failure(.init(message: error.localizedDescription))
        }
        guard let parentUid = file.parentFolder?.genericIdentifierWithinManagedObjectContext.sdkUid else {
            throw CoreDataFile.InvalidState(message: "Failed to get parent UID")
        }
        guard let activeRevision = file.activeRevision ?? file.activeRevisionDraft else {
            throw CoreDataFile.InvalidState(message: "Failed to get revision")
        }
        let fileRevision = try SDKFileRevision(revision: activeRevision)
        // TODO: finder-refactor, review highlight owner == creatorEmail ?
        let creatorEmail = file.directShares.first?.members.first?.inviter ?? ""

        let shareURLIsEmpty = try file.getContextShare().shareUrls.isEmpty

        self.sdkFileNode = SDKFileNode(
            uid: file.genericIdentifier.sdkUid,
            parentUid: parentUid,
            name: name,
            creationTime: file.createdDate.timeIntervalSince1970,
            trashTime: nil,
            nameAuthor: SDKAuthor(emailAddress: file.nameSignatureEmail, signatureVerificationError: nil),
            keyAuthor: SDKAuthor(emailAddress: file.signatureEmail, signatureVerificationError: nil),
            ownedBy: SDKOwnedBy(email: creatorEmail, organization: nil),
            mediaType: file.mimeType,
            totalStorageSize: Int64(file.size), // NOTE: this number is incorrect, don't use it
            activeRevision: fileRevision,
            isShared: file.isShared,
            isSharedByUrl: !shareURLIsEmpty,
            errors: []
        )
        self.local = NodeLocalDTO(node: file)
        self.canExport = file.activeRevision != nil && file.isDownloadable
        self.isBookmark = file is CoreDataBookmark
        self.isPhoto = file is CoreDataPhoto
        self.isLocalFile = file.isLocalFile
        self.isProtonFile = file.isProtonFile
        self.uploadID = file.uploadID
    }
}

// MARK: - File only conveniences (false / nil for folders)
public extension NodeDTO {
    var isFile: Bool {
        switch self {
        case .file: return true
        case .folder: return false
        }
    }
    
    var canExport: Bool {
        switch self {
        case .file(let file): return file.canExport
        case .folder:  return false
        }
    }

    var isBookmark: Bool {
        switch self {
        case .file(let file): return file.isBookmark
        case .folder: return false
        }
    }

    var isPhoto: Bool {
        switch self {
        case .file(let file): return file.isPhoto
        case .folder: return false
        }
    }

    var isLocalFile: Bool {
        switch self {
        case .file(let file): return file.isLocalFile
        case .folder: return false
        }
    }

    var isProtonFile: Bool {
        switch self {
        case .file(let file): return file.isProtonFile
        case .folder: return false
        }
    }

    var uploadID: UUID? {
        switch self {
        case .file(let file): return file.uploadID
        case .folder: return nil
        }
    }
}
