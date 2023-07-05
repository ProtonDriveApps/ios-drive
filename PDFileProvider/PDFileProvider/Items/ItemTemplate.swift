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
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public class ItemTemplate: NSObject, NSFileProviderItem {
    
    public init(itemIdentifier: NSFileProviderItemIdentifier? = nil, parentId: NSFileProviderItemIdentifier, filename: String, type: String) {
        self.itemIdentifier = itemIdentifier ?? .init(UUID().uuidString)
        self.parentItemIdentifier = parentId
        self.filename = filename

        self.itemVersion = .init()

        #if os(OSX)
        self.contentType = UTType(type) ?? .data
        #else
        self.typeIdentifier = type
        #endif
        
        super.init()

        let metadataVersion = MetadataVersion(item: self).encoded()
        self.itemVersion = .init(contentVersion: Data(), metadataVersion: metadataVersion)
    }

    public init(item: NodeItem) {
        self.itemIdentifier = item.itemIdentifier
        self.parentItemIdentifier = item.parentItemIdentifier
        self.filename = item.filename

        self.itemVersion = item.itemVersion

        #if os(OSX)
        self.contentType = item.contentType
        #else
        self.typeIdentifier = item.contentType.identifier
        #endif

        super.init()

        self.itemVersion = item.itemVersion
    }
    
    public var itemIdentifier: NSFileProviderItemIdentifier
    public var parentItemIdentifier: NSFileProviderItemIdentifier
    public var filename: String
    public var itemVersion: NSFileProviderItemVersion
    #if os(OSX)
    public var contentType: UTType
    #else
    public var typeIdentifier: String
    #endif
}

public class ItemPlaceholder: NSObject, NSFileProviderItem {
    
    public init(id: NSFileProviderItemIdentifier) {
        self.itemIdentifier = id
        self.parentItemIdentifier = NSFileProviderItemIdentifier(rawValue: "")
        self.filename = ".\(UUID().uuidString)"
        
        super.init()
    }
    
    public var itemIdentifier: NSFileProviderItemIdentifier
    public var parentItemIdentifier: NSFileProviderItemIdentifier
    public var filename: String
}
