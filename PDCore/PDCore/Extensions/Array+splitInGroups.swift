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
        guard size != .zero else {
            return []
        }
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
    /// Splits by share and volume
    public func splitIntoChunks() -> [(share: String, volume: String, links: [String])] {
        // Group nodeIdentifiers by a tuple of (shareID, volumeID)
        let groupedByShareAndVolume = Dictionary(grouping: self, by: { ShareVolumeKey(shareID: $0.shareID, volumeID: $0.volumeID) })

        // Transform NodeIdentifier to nodeID and include both shareID and volumeID
        var result: [(share: String, volume: String, links: [String])] = []
        for (key, nodeIDs) in groupedByShareAndVolume {
            let nodeIDStrings = nodeIDs.map { $0.nodeID }
            let chunks = nodeIDStrings.splitInGroups(of: 150)
            for chunk in chunks {
                result.append((share: key.shareID, volume: key.volumeID, links: chunk))
            }
        }

        return result
    }

    private struct ShareVolumeKey: Hashable {
        let shareID: String
        let volumeID: String
    }
}

extension Array where Element == TrashingNodeIdentifier {
    func splitIntoChunks() -> [(volume: String, share: String, parent: String, links: [String])] {
        // Group TrashingNodeIdentifiers by shareID and parentID using a hashable struct
        let groupedById = Dictionary(grouping: self) { Parent(volumeID: $0.volumeID, shareID: $0.shareID, parentID: $0.parentID) }

        // Transform TrashingNodeIdentifier to nodeID
        let transformedGroup: [Parent: [String]] = groupedById.mapValues { $0.map { $0.nodeID } }

        // Split each group into chunks of maximum size 150
        var result: [(volume: String, share: String, parent: String, links: [String])] = []
        for (key, nodeIDs) in transformedGroup {
            let chunks = nodeIDs.splitInGroups(of: 150)
            for chunk in chunks {
                result.append((key.volumeID, key.shareID, key.parentID, chunk))
            }
        }

        return result
    }

    private struct Parent: Hashable {
        let volumeID: String
        let shareID: String
        let parentID: String
    }
}

public extension Array where Element: VolumeIdentifiable {
    func splitIntoChunksByVolume() -> [(volumeId: String, nodeIds: [String])] {
        // Group nodeIdentifiers by volumeID
        let groupedByShareAndVolume = Dictionary(grouping: self, by: { $0.volumeID })

        // Transform NodeIdentifier to nodeID and include both shareID and volumeID
        var result: [(volumeId: String, nodeIds: [String])] = []
        for (key, nodeIDs) in groupedByShareAndVolume {
            let nodeIDStrings = nodeIDs.map { $0.id }
            let chunks = nodeIDStrings.splitInGroups(of: 150)
            for chunk in chunks {
                result.append((volumeId: key, nodeIds: chunk))
            }
        }

        return result
    }
}
