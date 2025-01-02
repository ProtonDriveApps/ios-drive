// Copyright (c) 2024 Proton AG
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

import PDClient

extension Array where Element == SharedByMeListResponse.Link {
    func toLinksMetadataParameters() -> [LinksMetadataParameters] {
        // Group links by contextShareID
        let groupedLinks = Dictionary(grouping: self, by: { $0.contextShareID })

        var metadataParameters: [LinksMetadataParameters] = []

        for (shareId, links) in groupedLinks {
            // Extract link IDs and split them into groups of 50
            let linkIds = links.map { $0.linkID }
            let chunks = linkIds.splitInGroups(of: 50)

            // Create LinksMetadataParameters for each chunk
            for chunk in chunks {
                let metadata = LinksMetadataParameters(shareId: shareId, linkIds: chunk)
                metadataParameters.append(metadata)
            }
        }

        return metadataParameters
    }
}
