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
public var PDFileProviderDecryptName: (Node) throws -> String = { try $0.decryptNameWithCryptoGo(signatureKeys: []) }
#endif

public class NodeItem: NSObject, NSFileProviderItem {

    public convenience init(node: Node) throws {
        guard let moc = node.moc else {
            throw Node.noMOC()
        }
        let properties = try moc.performAndWait {
            try NodeItem.extractProperties(from: node)
        }
        self.init(properties: properties)
    }

    public convenience init(nodeWithinManagedObjectContext: Node) throws {
        let properties = try NodeItem.extractProperties(from: nodeWithinManagedObjectContext)
        self.init(properties: properties)
    }

    // swiftlint:disable:next function_body_length
    private init(properties: NodeProperties) {
        self.itemIdentifier = properties.itemIdentifier
        self.parentItemIdentifier = properties.parentItemIdentifier

        self.capabilities = []
        self.itemVersion = .init()
        self.contentType = properties.contentType

        #if os(iOS)
        self.isTrashed = properties.isTrashed
        self.isDownloaded = properties.isDownloaded
        #endif

        self.isUploaded = properties.isUploaded
        #if os(macOS)
        self.filename = properties.filesystemFilename
        #else
        self.filename = properties.filename
        #endif
        self.creationDate = properties.creationDate
        self.contentModificationDate = properties.contentModificationDate
        self.documentSize = properties.documentSize

        self.userInfo = properties.userInfo

        #if os(macOS)
        // properties related to being shared are set to false because of Apple's bug mentioning "iCloud" as the file provider
        // see https://forums.developer.apple.com/forums/thread/755818
        self.isShared = false
        self.decorations = properties.decorations
        self.contentPolicy = properties.contentPolicy
        #else
        self.isShared = properties.isShared
        #endif
        self.childItemCount = properties.childItemCount
        self.capabilities = properties.capabilities

        self.itemVersion = .init(contentVersion: properties.contentVersion, metadataVersion: properties.metadataVersion)

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

    private struct NodeProperties {
        let filename: String
        let filesystemFilename: String
        let itemIdentifier: NSFileProviderItemIdentifier
        let parentItemIdentifier: NSFileProviderItemIdentifier
        let contentType: UTType
        #if os(iOS)
        let isTrashed: Bool
        let isDownloaded: Bool
        #endif
        let isUploaded: Bool
        let creationDate: Date
        let contentModificationDate: Date
        let documentSize: NSNumber
        let isShared: Bool
        let childItemCount: NSNumber?
        let userInfo: [AnyHashable: Any]
        #if os(macOS)
        let decorations: [NSFileProviderItemDecorationIdentifier]?
        let contentPolicy: NSFileProviderContentPolicy
        #endif
        let capabilities: NSFileProviderItemCapabilities
        let contentVersion: Data
        let metadataVersion: Data
    }

    private static func extractProperties(from node: Node) throws -> NodeProperties {

        #if os(macOS)
        let filename = try PDFileProviderDecryptName(node)
        #else
        let filename = try node.decryptName()
        #endif
        var filesystemFilename = filename.filenameSanitizedForFilesystem()
        filesystemFilename = filesystemFilename.appendingProtonExtensionIfNecessary(basedOn: node.mimeType)

        guard !filesystemFilename.isEmpty else {
            Log.debug("Filename must not be empty. Node: \(node.id)", domain: .fileProvider)
            throw Errors.invalidFilename(filename: filename)
        }

        let itemIdentifier: NSFileProviderItemIdentifier
        let parentItemIdentifier: NSFileProviderItemIdentifier

        if let folder = node as? Folder, folder.isRoot { // root
            itemIdentifier = .rootContainer
            parentItemIdentifier = .rootContainer
        } else if node.state == .deleted {
            itemIdentifier = .init(node.identifier)
            // this is a workaround so that the deleted items are not visible anywhere
            // neither in the trash nor in the domain
            parentItemIdentifier = .init(rawValue: "")
        } else if let parent = node.parentNode, parent.parentNode == nil { // in root
            itemIdentifier = .init(node.identifier)
            parentItemIdentifier = .rootContainer
        } else if let parent = node.parentNode { // in folder
            itemIdentifier = .init(node.identifier)
            parentItemIdentifier = .init(parent.identifier)
        } else {
            // Non-root, non-deleted node without a parent: shouldn't happen, but fall back
            // to root rather than crashing. The node will surface at the top level.
            itemIdentifier = .init(node.identifier)
            parentItemIdentifier = .rootContainer
        }

        let defaultMIME = "application/octet-stream"
        let uti: UTType
        if node.mimeType == defaultMIME {
            uti = UTType(filenameExtension: filename.fileExtension) ?? .data
        } else {
            uti = UTType(mimeType: node.mimeType) ?? .data
        }
        let contentType = (node is Folder) ? .folder : uti

        #if os(iOS)
        let isTrashed = node.state == .deleted
        let isDownloaded = node.isDownloaded
        #endif

        let isUploaded = node.state == .active
        let creationDate = node.createdDate

        let activeRevision = (node as? File)?.activeRevision
        let contentModificationDate: Date
        if !MimeType(value: node.mimeType).isProtonFile,
           let activeRevision,
           let created = try? ISO8601DateFormatter.date(activeRevision.unsafeDecryptedExtendedAttributes().common?.modificationTime) ?? activeRevision.created {
            contentModificationDate = created
        } else {
            contentModificationDate = node.modifiedDate
        }

        let documentSize = NSNumber(value: node.presentableNodeSize)

        let isShared = NodeItem.isShared(node)

        let childItemCount: NSNumber?
        if let folder = node as? Folder {
            childItemCount = .init(value: folder.children.count)
        } else {
            childItemCount = nil
        }

        var userInfo = [AnyHashable: Any]()
        userInfo["keep_downloaded"] = node.isMarkedOfflineAvailable
        userInfo["inherit_keep_downloaded"] = node.isInheritingOfflineAvailable

#if os(macOS)
        let decorations = NodeItem.decorations(node)
        let contentPolicy = NodeItem.contentPolicy(node)
#endif
        let capabilities = NodeItem.capabilities(node)

        let contentVersion = ContentVersion(node: node).encoded()

        let metadataVersion = MetadataVersion(parentItemIdentifier: parentItemIdentifier, filename: filename).encoded()
#if os(iOS)
        return NodeProperties(
            filename: filename,
            filesystemFilename: filesystemFilename,
            itemIdentifier: itemIdentifier,
            parentItemIdentifier: parentItemIdentifier,
            contentType: contentType,
            isTrashed: isTrashed,
            isDownloaded: isDownloaded,
            isUploaded: isUploaded,
            creationDate: creationDate,
            contentModificationDate: contentModificationDate,
            documentSize: documentSize,
            isShared: isShared,
            childItemCount: childItemCount,
            userInfo: userInfo,
            capabilities: capabilities,
            contentVersion: contentVersion,
            metadataVersion: metadataVersion
        )
#elseif os(macOS)
        return NodeProperties(
            filename: filename,
            filesystemFilename: filesystemFilename,
            itemIdentifier: itemIdentifier,
            parentItemIdentifier: parentItemIdentifier,
            contentType: contentType,
            isUploaded: isUploaded,
            creationDate: creationDate,
            contentModificationDate: contentModificationDate,
            documentSize: documentSize,
            isShared: isShared,
            childItemCount: childItemCount,
            userInfo: userInfo,
            decorations: decorations,
            contentPolicy: contentPolicy,
            capabilities: capabilities,
            contentVersion: contentVersion,
            metadataVersion: metadataVersion
        )
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

extension NodeItem {
    var nodeID: String {
        NodeIdentifier(itemIdentifier)?.nodeID ?? itemIdentifier.rawValue
    }
}
