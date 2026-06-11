// Copyright (c) 2025 Proton AG
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

public protocol RemoteMetadataFetchRepositoryProtocol {
    func fetch(identifiers: [AnyVolumeIdentifier], forceToRefresh: Bool) async throws -> [AnyVolumeIdentifier]
}

final class RemoteMetadataFetchRepository: RemoteMetadataFetchRepositoryProtocol {
    private let cacher: MetadataCache
    private let client: RemoteLinksMetadataByVolumeDataSource

    init(cacher: MetadataCache, client: RemoteLinksMetadataByVolumeDataSource) {
        self.cacher = cacher
        self.client = client
    }

    func fetch(identifiers: [AnyVolumeIdentifier], forceToRefresh: Bool) async throws -> [AnyVolumeIdentifier] {
        let fetchedIDs, remoteIDs: [AnyVolumeIdentifier]
        if forceToRefresh {
            fetchedIDs = []
            remoteIDs = identifiers
        } else {
            (fetchedIDs, remoteIDs) = await classify(identifiers: identifiers)
        }
        let chunks = remoteIDs.splitIntoChunksByVolume()
        let links = try await withThrowingTaskGroup(of: [Link].self) { [weak self] taskGroup in
            for chunk in chunks {
                taskGroup.addTask { [weak self] in
                    guard let self else { return [] }
                    let response = try await self.client.getMetadata(forLinks: chunk.nodeIds, inVolume: chunk.volumeId)
                    return response.sortedLinks
                }
            }
            var links: [Link] = []
            for try await result in taskGroup {
                links.append(contentsOf: result)
            }
            return links
        }
        try await cacher.cache(links: links)
        return fetchedIDs + links.map { AnyVolumeIdentifier(id: $0.linkID, volumeID: $0.volumeID) }
    }

    private func classify(
        identifiers: [AnyVolumeIdentifier]
    ) async -> (fetchedIDs: [AnyVolumeIdentifier], remoteIDs: [AnyVolumeIdentifier]) {
        var fetchedIDs: [AnyVolumeIdentifier] = []
        var remoteIDs: [AnyVolumeIdentifier] = []
        let results = await cacher.filterByCache(for: identifiers)
        for result in results {
            switch result.1 {
            case .ignored:
                continue
            case .remote:
                remoteIDs.append(result.0)
            case .fetched:
                fetchedIDs.append(result.0)
            }
        }
        return (fetchedIDs, remoteIDs)
    }
}
