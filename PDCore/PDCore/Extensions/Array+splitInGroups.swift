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
