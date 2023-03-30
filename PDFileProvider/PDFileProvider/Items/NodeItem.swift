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
        
        let contentVersion = self.contentVersion(node).data(using: .utf8) ?? Data()
        let metadataVersion = "\(self.metadataVersion())".data(using: .utf8) ?? Data()
        self.itemVersion = .init(contentVersion: contentVersion, metadataVersion: metadataVersion)
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
    
    #if os(OSX)
    public var contentType: UTType
    #else
    public var isTrashed: Bool
    public var contentType: UTType
    #endif
    
    /// Node.modified is not modified by Cloud when metadata changes, so we needed to come up with some workaround for versioning
    private func metadataVersion() -> Int {
        var hasher = Hasher()
        hasher.combine(isShared)
        hasher.combine(creationDate)
        hasher.combine(contentModificationDate)
        hasher.combine(documentSize)
        hasher.combine(childItemCount)
        hasher.combine(itemIdentifier)
        hasher.combine(parentItemIdentifier)
        hasher.combine(filename)
        return hasher.finalize()
    }
    
    /// Content version of a file is active revision id
    private func contentVersion(_ node: Node) -> String {
        // This logic is a workaround until BE will return activeRevision ID on GET /shares/ID/folders/ID/children endpoint:
        // node is File and has more than one revision in local metadata DB -> need to bump verison to id of active revision
        guard let file = node as? File, file.revisions.count > 1, let activeRevision = file.activeRevision else {
            return String(describing: node.modifiedDate)
        }
        
        // otherwise we can just use activeRevision ID to distinguish from previous revisions
        return activeRevision.id
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
