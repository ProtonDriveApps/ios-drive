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

public struct LinksResponse: Codable {
    public var code: Int
    public var links: [Link]
    public var parents: [Link]

    public init(code: Int, links: [Link], parents: [Link]) {
        self.code = code
        self.links = links
        self.parents = parents
    }

    public var sortedLinks: [Link] {
        let sorter = LinkHierarchySorter()
        return sorter.sort(links: parents + links)
    }
}

final class LinkHierarchySorter {
    
    func sort(links: [Link]) -> [Link] {
        var sorted: [Link] = []
        for link in links {
            guard let parentLinkID = link.parentLinkID else {
                // Parent id doesn't exist, root?
                sorted.insert(link, at: 0)
                continue
            }

            if let parentIndex = sorted.firstIndex(where: { $0.linkID == parentLinkID }) {
                // Parent link is in the sorted array, insert behind the parent
                sorted.insert(link, at: parentIndex + 1)
                continue
            }

            if let childrenIndex = sorted.firstIndex(where: { $0.parentLinkID == link.linkID }) {
                // Children link is in the sorted array, insert ahead the children
                sorted.insert(link, at: childrenIndex)
            } else {
                // There is no parent link yet
                sorted.append(link)
            }
        }
        return sorted
    }

}
