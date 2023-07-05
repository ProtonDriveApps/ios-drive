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

public class NodeItem: NSObject, NSFileProviderItem {
    
    public init(node: Node) {
        if let folder = node as? Folder, folder.isRoot { // root
            self.itemIdentifier = .rootContainer
            self.parentItemIdentifier = .rootContainer
        } else if node.state == .deleted {
            self.itemIdentifier = .init(node.identifier)
            self.parentItemIdentifier = .trashContainer
        } else if node.parentLink?.parentLink == nil { // in root
            self.itemIdentifier = .init(node.identifier)
            self.parentItemIdentifier = .rootContainer
        } else { // in folder
            self.itemIdentifier = .init(node.identifier)
            self.parentItemIdentifier = .init(node.parentLink!.identifier)
        }
        
        self.capabilities = []
        self.itemVersion = .init()
        let uti = UTType(mimeType: node.mimeType) ?? .data
        self.contentType = (node is Folder) ? .folder : uti

        #if os(iOS)
        self.isTrashed = node.state == .deleted
        #endif
        
        self.isUploaded = node.state == .active
        self.isDownloaded = node.isDownloaded
        self.filename = node.decryptedName
        self.creationDate = node.createdDate
        self.contentModificationDate = node.modifiedDate
        self.documentSize = .init(value: node.size)
        // Root item should not be a shared item
        self.isShared = node.directShares.first(where: \.isMain) == nil ? node.isShared : false
        
        if let folder = node as? Folder {
            self.childItemCount = .init(value: folder.children.count)
        }

        super.init()
        
        self.capabilities = self.capabilities(node)
        
        let contentVersion = self.contentVersion(node).encoded()
        let metadataVersion = self.metadataVersion().encoded()
        self.itemVersion = .init(contentVersion: contentVersion, metadataVersion: metadataVersion)
    }

    public convenience init(node: Node, filename: String) {
        self.init(node: node)
        self.filename = filename
    }

    public init(item: NSFileProviderItem, filename: String) {
        self.filename = filename

        self.itemIdentifier = item.itemIdentifier
        self.parentItemIdentifier = item.parentItemIdentifier

        self.capabilities = item.capabilities ?? []
        self.contentType = item.contentType ?? .folder
        self.isUploaded = item.isUploaded ?? false
        self.isDownloaded = item.isDownloaded ?? false
        self.creationDate = item.creationDate ?? Date()
        self.contentModificationDate = item.contentModificationDate ?? Date()
        self.documentSize = item.documentSize ?? 0
        self.isShared = item.isShared ?? false
        self.childItemCount = item.childItemCount ?? 0
                
        #if os(iOS)
        self.isTrashed = item.isTrashed ?? false
        #endif
        
        #if os(macOS)
        self.itemVersion = item.itemVersion ?? NSFileProviderItemVersion()
        #elseif os(iOS)
        if #available(iOS 16.0, *), let itemVersion = item.itemVersion {
            self.itemVersion = NSFileProviderItemVersion(contentVersion: itemVersion.contentVersion, metadataVersion: itemVersion.metadataVersion)
        } else {
            self.itemVersion = NSFileProviderItemVersion()
        }
        #endif

        super.init()
    }

    public var isUploaded: Bool
    public var isDownloaded: Bool
    public var isShared: Bool
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

    #if os(iOS)
    public var isTrashed: Bool
    #endif
    
    /// Node.modified is not modified by Cloud when metadata changes, so we needed to come up with some workaround for versioning
    private func metadataVersion() -> MetadataVersion {
        return MetadataVersion(item: self)
    }
    
    /// Content version of a file is active revision id
    private func contentVersion(_ node: Node) -> ContentVersion {
        return ContentVersion(node: node)
    }
    
    private func capabilities(_ node: Node) -> NSFileProviderItemCapabilities {
        // all but writing
        var capabilities: NSFileProviderItemCapabilities = [.allowsReading, .allowsReparenting, .allowsRenaming, .allowsTrashing, .allowsDeleting]
        
        if node is Folder {
            capabilities.insert(.allowsWriting)
            return capabilities
        } else {
            // macOS:
            //  files without locally available contents should not have .allowsWriting capability
            //  otherwise apps (eg. Preview for images) will hang after download complete and will not open the file
            //  on the other hand, this flaw does not affect files that were downloaded beforehand
            //
            // iOS:
            //  writing needs to be fixed later
            //
            #if os(OSX)
            capabilities.insert(.allowsEvicting)

            if node.isDownloaded {
                capabilities.insert(.allowsWriting)
            }
            #endif

            return capabilities
        }
    }
}
