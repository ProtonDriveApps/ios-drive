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
import PDClient
import PDLocalization

@objc public enum SortPreference: Int {
    case modifiedDescending = 0, sizeDescending, mimeDescending, nameDescending
    case modifiedAscending, sizeAscending, mimeAscending, nameAscending

    public static var `default`: SortPreference {
        .modifiedDescending
    }

    public var title: String {
        switch self {
        case .modifiedAscending, .modifiedDescending:
            return Localization.sort_type_last_modified
        case .sizeAscending, .sizeDescending:
            return Localization.sort_type_size
        case .mimeAscending, .mimeDescending:
            return Localization.sort_type_file_type
        case .nameAscending, .nameDescending:
            return Localization.sort_type_name
        }
    }

    public var isAscending: Bool {
        switch self {
        case .modifiedAscending, .sizeAscending, .mimeAscending, .nameAscending:
            return true
        case .modifiedDescending, .sizeDescending, .mimeDescending, .nameDescending:
            return false
        }
    }

    var keyPath: String {
        switch self {
        case .modifiedAscending, .modifiedDescending:
            return Node.modifiedDateKeyPath
        case .sizeAscending, .sizeDescending:
            return #keyPath(Node.size)
        case .mimeAscending, .mimeDescending:
            return #keyPath(Node.mimeType)
        case .nameAscending, .nameDescending:
            return #keyPath(Node.id)
        }
    }

    public var apiSorting: PDClient.FolderChildrenEndpointParameters.SortField? {
        switch self {
        case .modifiedAscending, .modifiedDescending:
            return .modified
        case .sizeAscending, .sizeDescending:
            return .size
        case .mimeAscending, .mimeDescending:
            return .mimeType
        case .nameAscending, .nameDescending:
            return nil
        }
    }

    public var apiOrder: PDClient.FolderChildrenEndpointParameters.SortOrder {
        self.isAscending ? .asc : .desc
    }
}

public extension SortPreference {
    var descriptor: NSSortDescriptor {
        NSSortDescriptor(key: self.keyPath, ascending: self.isAscending)
    }
}

public extension SortPreference {
    func sort(_ nodes: [Node]) -> [Node] {
        switch self {
        case .mimeAscending:
            return nodes.sorted(by: Self.foldersFirst,
                                Self.ascendingType,
                                Self.ascendingName)
        case .mimeDescending:
            return nodes.sorted(by: Self.filesFirst,
                                Self.descendingType,
                                Self.ascendingName)
        case .modifiedAscending:
            return nodes.sorted(by: Self.ascendingModified,
                                Self.ascendingName)
        case .modifiedDescending:
            return nodes.sorted(by: Self.descendingModified,
                                Self.ascendingName)
        case .sizeAscending:
            return nodes.sorted(by: Self.foldersFirst,
                                Self.ascendingSize,
                                Self.ascendingName)
        case .sizeDescending:
            return nodes.sorted(by: Self.filesFirst,
                                Self.descendingSize,
                                Self.ascendingName)
        case .nameAscending:
            return nodes.sorted(by: Self.foldersFirst,
                                Self.ascendingName)
        case .nameDescending:
            return nodes.sorted(by: Self.foldersFirst,
                                Self.descendingName)
        }
    }
}

private extension SortPreference {
    static let foldersFirst: (Node, Node) -> Bool = {
        $0 is Folder && $1 is File
    }

    static let filesFirst: (Node, Node) -> Bool = {
        $0 is File && $1 is Folder
    }

    static let ascendingSize: (Node, Node) -> Bool = {
        $0.size < $1.size
    }

    static let descendingSize: (Node, Node) -> Bool = {
        $0.size > $1.size
    }

    static let ascendingType: (Node, Node) -> Bool = {
        $0.mimeType < $1.mimeType
    }

    static let descendingType: (Node, Node) -> Bool = {
        $0.mimeType > $1.mimeType
    }

    static let ascendingName: (Node, Node) -> Bool = {
        $0.decryptedName.localizedCompare($1.decryptedName) == .orderedAscending
    }

    static let descendingName: (Node, Node) -> Bool = {
        $0.decryptedName.localizedCompare($1.decryptedName) == .orderedDescending
    }

    static let ascendingModified: (Node, Node) -> Bool = {
        $0.modifiedDate < $1.modifiedDate
    }

    static let descendingModified: (Node, Node) -> Bool = {
        $0.modifiedDate > $1.modifiedDate
    }
}
