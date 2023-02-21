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

public enum NodeType: String {
    case file = "File"
    case folder = "Folder"
    case mix = "Item"

    public var type: String {
        rawValue.lowercased()
    }
}

extension Node {
    /// Heavy operation including recursion, use carefully
    public func parentsChain() -> [Folder] {
        guard let parent = self.parentLink else { return [] }
        var chain = parent.parentsChain()
        chain.append(parent)
        return chain
    }
}

extension Node {
    /// Heavy operation including recursion, use carefully
    public var isDownloaded: Bool {
        switch self {
        case is File:
            return (self as? File)?.activeRevision?.blocksAreValid() ?? false
            
        case is Folder:
            guard let folder = self as? Folder else { return false }
            
            if !folder.isChildrenListFullyFetched {
                return false
            }
            
            // children Files - just checks the blocks
            if nil != folder.children
                .filter({ $0 is File })
                .first(where: { $0.isDownloaded == false })
            {
                return false
            }
            
            // children Folders - whether all children pages are fetched
            if nil != folder.children
                .compactMap({ $0 as? Folder })
                .first(where: { $0.isChildrenListFullyFetched == false })
            {
                return false
            }
            
            // children Folders - involves recusion over child's children
            if nil != folder.children
                .filter({ $0 is Folder })
                .first(where: { $0.isDownloaded == false })
            {
                return false
            }
            
            // did not find not-downloaded children in the subtree
            return true
            
        default:
            return false
        }
    }

    public var isTrashInheriting: Bool {
        guard let parent = parentLink else {
            return state == .deleted
        }
        if parent.state == .deleted {
            return true
        } else {
            return parent.isTrashInheriting
        }
    }
}
