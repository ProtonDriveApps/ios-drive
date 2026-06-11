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

import Foundation
import FileProvider

public struct NodeIdentifier: Equatable, Hashable {
    public let nodeID: String
    public let shareID: String
    public let volumeID: String

    public init(_ nodeID: String, _ shareID: String, _ volumeID: String) {
        self.nodeID = nodeID
        self.shareID = shareID
        self.volumeID = volumeID
    }
}

extension NodeIdentifier: VolumeIdentifiable {
    public var id: String {
        nodeID
    }
}

extension NodeIdentifier: RawRepresentable {
    public var rawValue: String {
        #if os(macOS)
        nodeID + "/" + shareID
        #else
        "\(volumeID)/\(nodeID)"
        #endif
    }
    
    public init?(rawValue: String) {
        guard case let parts = rawValue.components(separatedBy: "/"), parts.count == 2 else {
            return nil
        }
        #if os(macOS)
        self.init(parts.first!, parts.last!, "")
        #else
        self.init(parts.last!, "", parts.first!)
        #endif
    }
}

public extension Node {
    var identifier: NodeIdentifier {
        guard let moc else {
            return NodeIdentifier("", "", "")
        }

        return moc.performAndWait {
            self.identifierWithinManagedObjectContext
        }
    }
    
    var identifierWithinManagedObjectContext: NodeIdentifier {
        NodeIdentifier(self.id, self.shareId, self.volumeID) 
    }

    // Avoids share id lookup, which is costly and unnecessary
    var genericIdentifier: AnyVolumeIdentifier {
        guard let moc else {
            return AnyVolumeIdentifier(id: "", volumeID: "")
        }

        return moc.performAndWait {
            return AnyVolumeIdentifier(id: id, volumeID: volumeID)
        }
    }
    
    var genericIdentifierWithinManagedObjectContext: AnyVolumeIdentifier {
        return AnyVolumeIdentifier(id: id, volumeID: volumeID)
    }
    
    var volumeBasedIdentifier: NodeIdentifier {
        guard let moc else { return NodeIdentifier("", "", "") }
        return moc.performAndWait {
            volumeBasedIdentifierWithinManagedObjectContext
        }
    }
    
    var volumeBasedIdentifierWithinManagedObjectContext: NodeIdentifier {
        NodeIdentifier(id, "", volumeID)
    }
}

public extension File {
    var fileIdentifier: FileIdentifier {
        guard let pid = parentNode?.id else { fatalError("A file must have a parent link!") }
        return FileIdentifier(fileID: id, parentID: pid, shareID: shareId)
    }
}

public extension Collection where Element == NodeIdentifier {
    func contains(_ identifier: NodeIdentifier) -> Bool {
        self.contains { identifier.nodeID == $0.nodeID && identifier.shareID == $0.shareID }
    }
}

public struct FileIdentifier {
    let fileID: String
    let parentID: String
    let shareID: String
}

public struct RevisionIdentifier: Hashable, VolumeIdentifiable {
    public let shareID: String
    public let fileID: String
    public let revisionID: String
    public let volumeID: String

    public init(shareID: String, fileID: String, revisionID: String, volumeID: String) {
        self.shareID = shareID
        self.fileID = fileID
        self.revisionID = revisionID
        self.volumeID = volumeID
    }

    var nodeIdentifier: NodeIdentifier {
        NodeIdentifier(fileID, shareID, volumeID)
    }

    public var id: String {
        revisionID
    }
}
