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

import FileProvider
import Foundation
import PDCore
import UniformTypeIdentifiers
#if os(macOS)
public var PDFileProviderDecryptName: (Node) throws -> String = { try $0.decryptNameWithCryptoGo() }
#endif

public class NodeItem: NSObject, NSFileProviderItem {

    // swiftlint:disable:next function_body_length
    public init(node: Node) throws {
        guard let moc = node.moc else {
            throw Node.noMOC()
        }

        var itemIdentifier: NSFileProviderItemIdentifier!
        var parentItemIdentifier: NSFileProviderItemIdentifier!
        var contentType: UTType!
        var isUploaded: Bool!
        #if os(iOS)
        var isTrashed: Bool!
        var isDownloaded: Bool!
        #endif
        var filename: String!
        var filesystemFilename: String!
        var creationDate: Date!
        var contentModificationDate: Date!
        var documentSize: NSNumber!
        var isShared: Bool!
#if os(macOS)
        var decorations: [NSFileProviderItemDecorationIdentifier]!
        var contentPolicy: NSFileProviderContentPolicy!
#endif
        var childItemCount: NSNumber!
        var capabilities: NSFileProviderItemCapabilities!
        var contentVersion: Data!
        var userInfo = [AnyHashable: Any]()

        try moc.performAndWait {
            #if os(macOS)
            filename = try PDFileProviderDecryptName(node)
            #else
            filename = try node.decryptName()
            #endif
            filesystemFilename = filename.filenameSanitizedForFilesystem()
            filesystemFilename = filesystemFilename.appendingProtonExtensionIfNecessary(basedOn: node.mimeType)

            guard !filesystemFilename.isEmpty else {
                Log.debug("Filename must not be empty. Node: \(node)", domain: .fileProvider)
                throw Errors.invalidFilename(filename: filename)
            }

            if let folder = node as? Folder, folder.isRoot { // root
                itemIdentifier = .rootContainer
                parentItemIdentifier = .rootContainer
            } else if node.state == .deleted {
                itemIdentifier = .init(node.identifier)
                // this is a workaround so that the deleted items are not visible anywhere
                // neither in the trash nor in the domain
                parentItemIdentifier = .init(rawValue: "")
            } else if node.parentNode?.parentNode == nil { // in root
                itemIdentifier = .init(node.identifier)
                parentItemIdentifier = .rootContainer
            } else { // in folder
                itemIdentifier = .init(node.identifier)
                parentItemIdentifier = .init(node.parentLink!.identifier)
            }

            let defaultMIME = "application/octet-stream"
            let uti: UTType
            if node.mimeType == defaultMIME {
                uti = UTType(filenameExtension: filename.fileExtension) ?? .data
            } else {
                uti = UTType(mimeType: node.mimeType) ?? .data
            }
            contentType = (node is Folder) ? .folder : uti

            #if os(iOS)
            isTrashed = node.state == .deleted
            isDownloaded = node.isDownloaded
            #endif

            isUploaded = node.state == .active
            creationDate = node.createdDate

            let activeRevision = (node as? File)?.activeRevision
            if MimeType(value: node.mimeType) != MimeType.protonDoc,
               let activeRevision,
               let created = try? ISO8601DateFormatter().date(activeRevision.decryptedExtendedAttributes().common?.modificationTime) ?? activeRevision.created {
                contentModificationDate = created
            } else {
                contentModificationDate = node.modifiedDate
            }

            documentSize = NSNumber(value: node.presentableNodeSize)

            isShared = NodeItem.isShared(node)

            if let folder = node as? Folder {
                childItemCount = .init(value: folder.children.count)
            }

            userInfo["keep_downloaded"] = node.isMarkedOfflineAvailable
            userInfo["inherit_keep_downloaded"] = node.isInheritingOfflineAvailable

#if os(macOS)
            decorations = NodeItem.decorations(node)
            contentPolicy = NodeItem.contentPolicy(node)
#endif
            capabilities = NodeItem.capabilities(node)

            contentVersion = ContentVersion(node: node).encoded()
        }

        self.itemIdentifier = itemIdentifier
        self.parentItemIdentifier = parentItemIdentifier

        self.capabilities = []
        self.itemVersion = .init()
        self.contentType = contentType

        #if os(iOS)
        self.isTrashed = isTrashed
        self.isDownloaded = isDownloaded
        #endif

        self.isUploaded = isUploaded
        #if os(macOS)
        self.filename = filesystemFilename
        #else
        self.filename = filename
        #endif
        self.creationDate = creationDate
        self.contentModificationDate = contentModificationDate
        self.documentSize = documentSize

        self.userInfo = userInfo

        #if os(macOS)
        // properties related to being shared are set to false because of Apple's bug mentioning "iCloud" as the file provider
        // see https://forums.developer.apple.com/forums/thread/755818
        self.isShared = false
        self.decorations = decorations
        self.contentPolicy = contentPolicy
        #else
        self.isShared = isShared
        #endif
        self.childItemCount = childItemCount
        self.capabilities = capabilities

        let metadataVersion = MetadataVersion(parentItemIdentifier: parentItemIdentifier, filename: filename).encoded()
        self.itemVersion = .init(contentVersion: contentVersion, metadataVersion: metadataVersion)

        super.init()
    }

    public init(item: NSFileProviderItem, filename: String) {
        self.filename = filename

        self.itemIdentifier = item.itemIdentifier
        self.parentItemIdentifier = item.parentItemIdentifier

        self.capabilities = item.capabilities ?? []
        #if os(macOS)
        self.contentPolicy = item.contentPolicy ?? .inherited
        #endif
        self.contentType = item.contentType ?? .folder
        self.isUploaded = item.isUploaded ?? false
        self.creationDate = item.creationDate ?? Date()
        self.contentModificationDate = item.contentModificationDate ?? Date()
        self.documentSize = item.documentSize ?? 0
        self.isShared = item.isShared ?? false
        self.childItemCount = item.childItemCount ?? 0
                
        #if os(iOS)
        self.isTrashed = item.isTrashed ?? false
        self.isDownloaded = item.isDownloaded ?? false
        #endif
        
        #if os(macOS)
        self.itemVersion = item.itemVersion ?? NSFileProviderItemVersion()
        #else
        if let itemVersion = item.itemVersion {
            self.itemVersion = NSFileProviderItemVersion(contentVersion: itemVersion.contentVersion, metadataVersion: itemVersion.metadataVersion)
        } else {
            self.itemVersion = NSFileProviderItemVersion()
        }
        #endif

        super.init()
    }

    public var isUploaded: Bool
    public var isShared: Bool
    #if os(macOS)
    public var decorations: [NSFileProviderItemDecorationIdentifier]?
    public var contentPolicy: NSFileProviderContentPolicy
    #endif
    public var creationDate: Date?
    public var contentModificationDate: Date?
    public var documentSize: NSNumber?
    public var childItemCount: NSNumber?
    public var itemIdentifier: NSFileProviderItemIdentifier
    public var parentItemIdentifier: NSFileProviderItemIdentifier
    public var filename: String
    public var itemVersion: NSFileProviderItemVersion
    public var capabilities: NSFileProviderItemCapabilities
    public var contentType: UTType
    public var userInfo: [AnyHashable: Any]?

    #if os(iOS)
    public var isTrashed: Bool
    public var isDownloaded: Bool
    #endif

    private static let decorationPrefix = "me.proton.drive.fileproviderdecorations"
    private static let sharedDecorationPrefix = "\(decorationPrefix).shared"
    private static let badgeDecorationPrefix = "\(decorationPrefix).badge"
    private static let sharedLabelDecoration = NSFileProviderItemDecorationIdentifier(rawValue: "\(sharedDecorationPrefix).label")
    private static let sharedFolderDecoration = NSFileProviderItemDecorationIdentifier(rawValue: "\(sharedDecorationPrefix).folderBadge")
    private static let sharedFileDecoration = NSFileProviderItemDecorationIdentifier(rawValue: "\(sharedDecorationPrefix).file")
    private static let keepDownloadedDecoration = NSFileProviderItemDecorationIdentifier(rawValue: "\(badgeDecorationPrefix).checkmark")

    private static func decorations(_ node: Node) -> [NSFileProviderItemDecorationIdentifier]? {
        let isShared = NodeItem.isShared(node)
        var decorations = [NSFileProviderItemDecorationIdentifier]()
        if isShared && node is Folder {
            decorations = [
                sharedLabelDecoration,
                sharedFolderDecoration
            ]
        } else if isShared && node is File {
            decorations = [
                sharedFileDecoration
            ]
        }

        if node.isAvailableOffline {
            decorations.append(keepDownloadedDecoration)
        }

        return !decorations.isEmpty ? decorations : nil
    }

    private static func isShared(_ node: Node) -> Bool {
        // Root item should not be a shared item
        return node.directShares.first(where: \.isMain) == nil
            ? !node.directShares.isEmpty
            : false
    }

    private static func capabilities(_ node: PDCore.Node) -> NSFileProviderItemCapabilities {
        // all but writing
        var capabilities: NSFileProviderItemCapabilities = [.allowsReading, .allowsReparenting, .allowsRenaming, .allowsTrashing, .allowsDeleting]
        
        if node is Folder {
            capabilities.insert(.allowsWriting)
            return capabilities
        } else {
            // macOS:
            //  Ideally we should not force allowsWriting if the permissions of the original file did not allow writing.
            // But that is a fix for another day to properly support file permissions.
            //
            // iOS:
            //  writing needs to be fixed later
            //
            #if os(macOS)
            if !MimeType(value: node.mimeType).isProtonFile {
                capabilities.insert(.allowsWriting)
            }
            #endif

            return capabilities
        }
    }

    private static func contentPolicy(_ node: Node) -> NSFileProviderContentPolicy {
        #if os(macOS)
        if node.isMarkedOfflineAvailable {
            return .downloadEagerlyAndKeepDownloaded
        } else if node.isInheritingOfflineAvailable {
            return .inherited
        } else {
            return .downloadLazily
        }
        #else
        return .inherited
        #endif
    }

    #if os(macOS)
    override public var debugDescription: String {
        """
        isUploaded: \(isUploaded) \
        isShared: \(isShared) \
        decorations: \(String(describing: decorations)) \
        creationDate: \(String(describing: creationDate)) \
        contentModificationDate: \(String(describing: contentModificationDate)) \
        documentSize: \(String(describing: documentSize)) \
        childItemCount: \(String(describing: childItemCount)) \
        itemIdentifier: \(itemIdentifier) \
        parentItemIdentifier: \(parentItemIdentifier) \
        filename: \(filename) \
        itemVersion.metadataVersion: \(itemVersion.metadataVersion) \
        itemVersion.contentVersion: \(itemVersion.contentVersion) \
        capabilities: \(capabilities) \
        contentType: \(contentType)
        """
    }
    #endif
}

#if os(macOS)
extension NodeItem: NSFileProviderItemDecorating {}
#endif

public extension NodeItem {

    static func areEqualPropertyWise(lhs: NodeItem, rhs: NodeItem, ignoringCreationDate: Bool = false) -> Bool {
        let areBaseFieldsSame = lhs.isUploaded == rhs.isUploaded &&
            lhs.isShared == rhs.isShared &&
            lhs.contentModificationDate == rhs.contentModificationDate &&
            lhs.documentSize == rhs.documentSize &&
            lhs.childItemCount == rhs.childItemCount &&
            lhs.itemIdentifier == rhs.itemIdentifier &&
            lhs.parentItemIdentifier == rhs.parentItemIdentifier &&
            lhs.filename == rhs.filename &&
            lhs.capabilities == rhs.capabilities &&
            lhs.contentType == rhs.contentType
        let isCreationDateSame = ignoringCreationDate ? true : lhs.creationDate == rhs.creationDate
#if os(macOS)
        return areBaseFieldsSame &&
            isCreationDateSame &&
            lhs.decorations == rhs.decorations &&
            lhs.itemVersion.contentVersion == rhs.itemVersion.contentVersion &&
            MetadataVersion(from: lhs.itemVersion.metadataVersion)! == MetadataVersion(from: rhs.itemVersion.metadataVersion)!
#endif
#if os(iOS)
        return areBaseFieldsSame && isCreationDateSame && lhs.isTrashed == rhs.isTrashed && lhs.isDownloaded == rhs.isDownloaded
#endif
    }
}
