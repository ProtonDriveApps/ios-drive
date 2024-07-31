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

    public init(_ nodeID: String, _ shareID: String) {
        self.nodeID = nodeID
        self.shareID = shareID
    }
}

extension NodeIdentifier: RawRepresentable {
    public var rawValue: String {
        nodeID + "/" + shareID
    }
    
    public init?(rawValue: String) {
        guard case let parts = rawValue.components(separatedBy: "/"), parts.count == 2 else {
            return nil
        }
        self.init(parts.first!, parts.last!)
    }
}

public extension Node {
    var identifier: NodeIdentifier {
        guard let moc else {
            return NodeIdentifier("", "")
        }

        return moc.performAndWait {
            self.identifierWithinManagedObjectContext
        }
    }
    
    var identifierWithinManagedObjectContext: NodeIdentifier {
        NodeIdentifier(self.id, self.shareID)
    }
}

public extension File {
    var fileIdentifier: FileIdentifier {
        guard let pid = parentLink?.id else { fatalError("A file must have a parent link!") }
        return FileIdentifier(fileID: id, parentID: pid, shareID: shareID)
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

public struct RevisionIdentifier: Hashable {
    public let share: String
    public let file: String
    public let revision: String

    public init(share: String, file: String, revision: String) {
        self.share = share
        self.file = file
        self.revision = revision
    }

    var nodeIdentifier: NodeIdentifier {
        NodeIdentifier(file, share)
    }
}
