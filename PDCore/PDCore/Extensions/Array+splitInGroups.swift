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

extension Array {
    public func splitInGroups(of size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    public func partitioned(by predicate: (Element) -> Bool) -> (trueElements: [Element], falseElements: [Element]) {
        var trueElements: [Element] = []
        var falseElements: [Element] = []
        for element in self {
            if predicate(element) {
                trueElements.append(element)
            } else {
                falseElements.append(element)
            }
        }
        return (trueElements, falseElements)
    }
}

extension Array where Element == NodeIdentifier {
    public func splitIntoChunks() -> [(share: String, links: [String])] {
        // Group nodeIdentifiers by shareID
        let groupedById = Dictionary(grouping: self, by: { $0.shareID })

        // Transform NodeIdentifier to nodeID
        let transformedGroup: [String: [String]] = groupedById.mapValues { $0.map { $0.nodeID } }

        // Split each group into chunks of maximum size 150
        var result: [(String, [String])] = []
        for (shareID, nodeIDs) in transformedGroup {
            let chunks = nodeIDs.splitInGroups(of: 150)
            for chunk in chunks {
                result.append((shareID, chunk))
            }
        }

        return result
    }
}

extension Array where Element == TrashingNodeIdentifier {
    func splitIntoChunks() -> [(share: String, parent: String, links: [String])] {
        // Group TrashingNodeIdentifiers by shareID and parentID using a hashable struct
        let groupedById = Dictionary(grouping: self) { Parent(shareID: $0.shareID, parentID: $0.parentID) }

        // Transform TrashingNodeIdentifier to nodeID
        let transformedGroup: [Parent: [String]] = groupedById.mapValues { $0.map { $0.nodeID } }

        // Split each group into chunks of maximum size 150
        var result: [(share: String, parent: String, links: [String])] = []
        for (key, nodeIDs) in transformedGroup {
            let chunks = nodeIDs.splitInGroups(of: 150)
            for chunk in chunks {
                result.append((key.shareID, key.parentID, chunk))
            }
        }

        return result.sorted(by: { $0.share < $1.share }, { $0.parent < $1.parent })
    }

    private struct Parent: Hashable {
        let shareID: String
        let parentID: String
    }
}
