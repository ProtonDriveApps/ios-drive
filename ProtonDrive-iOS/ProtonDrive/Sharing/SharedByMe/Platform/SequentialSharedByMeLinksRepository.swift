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
import PDCore
final class SequentialSharedByMeLinksRepository: SharedByMeLinksRepository {

    private let volumeId: String
    private let sharedByMeLinkIdsDataSource: SharedByMeLinkIdsDataSource
    private let linksMetadataDataSource: LinksMetadataDataSource
    private let storage: StorageManager

    init(
        volumeId: String,
        sharedByMeLinkIdsDataSource: SharedByMeLinkIdsDataSource,
        linksMetadataDataSource: LinksMetadataDataSource,
        storage: StorageManager
    ) {
        self.volumeId = volumeId
        self.sharedByMeLinkIdsDataSource = sharedByMeLinkIdsDataSource
        self.linksMetadataDataSource = linksMetadataDataSource
        self.storage = storage
    }

    func getLinks() async throws {
        let sharedByMeLinkIds = try await fetchSharedByMeLinksIds()

        let groupedLinkMetadataParameters = sharedByMeLinkIds.toLinksMetadataParameters()

        for group in groupedLinkMetadataParameters {
            try await fetchAndCachePairs(parametersGroup: group)
        }
    }

    private func fetchSharedByMeLinksIds() async throws -> [SharedByMeListResponse.Link] {
        var links = [SharedByMeListResponse.Link]()
        let validator = makeSupportedSharesValidator()
        var more = false
        var anchorId: String?

        repeat {
            let response = try await fetchLinks(volumeId: volumeId, anchorId: anchorId)
            links += response.links.filter { validator.isValid($0.contextShareID) }
            more = response.more
            anchorId = response.anchorID
        } while more

        return links
    }

    private func fetchLinks(volumeId: String, anchorId: String?) async throws -> SharedByMeListResponse {
        let parameters = SharedByMeListParameters(volumeId: volumeId, anchorID: anchorId)
        return try await sharedByMeLinkIdsDataSource.getSharedByMeLinks(parameters: parameters)
    }

    private func fetchAndCachePairs(parametersGroup params: LinksMetadataParameters) async throws {
        let linkResponse = try await self.linksMetadataDataSource.getLinksMetadata(with: params)
        let linksMetadata = linkResponse.sortedLinks

        // Perform caching in a single task to ensure order
        try await self.storage.backgroundContext.perform {
            // Save parents first
            self.storage.updateLinks(linksMetadata, in: self.storage.backgroundContext)

            // Save changes to context
            try self.storage.backgroundContext.saveOrRollback()
        }
    }

    private func makeSupportedSharesValidator() -> SupportedSharesValidator {
        iOSSupportedSharesValidator(storage: storage)
    }
}
