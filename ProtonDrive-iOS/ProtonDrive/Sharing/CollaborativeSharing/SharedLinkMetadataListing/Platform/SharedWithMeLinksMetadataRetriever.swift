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

import Foundation
import PDClient
import PDCore

final class SharedWithMeLinksMetadataRetriever: SharedLinkRetriever {
    private let client: Client
    private let sharedLinkIdDataSource: SharedLinkIdDataSource
    private let metadataCacher: SharedWithMeMetadataCache

    init(client: Client, dataSource: SharedLinkIdDataSource, cacher: SharedWithMeMetadataCache) {
        self.client = client
        self.sharedLinkIdDataSource = dataSource
        self.metadataCacher = cacher
    }

    func retrieve() async throws {
        let links = sharedLinkIdDataSource.getLinks()

        guard !links.isEmpty else {
            Log.info("No shared links to process.", domain: .sharing)
            return
        }

        let pairs = links.splitInGroups(of: 50)

        for pairChunk in pairs {
            try await fetchAndCachePairs(pairs: pairChunk)
        }
    }

    private func fetchAndCachePairs(pairs: [ShareLink]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for pair in pairs {
                group.addTask {
                    async let shareResponse = try await self.client.bootstrapShare(id: pair.share)
                    async let linkResponse = try await self.client.getLinksMetadata(with: .init(shareId: pair.share, linkIds: [pair.link]))
                    let (fetchedShare, fetchedLink) = try await (shareResponse, linkResponse.links[0])
                    try await self.metadataCacher.cache(fetchedLink, fetchedShare)
                }
            }

            // Await all tasks in the group to complete
            try await group.waitForAll()
        }
    }
}
