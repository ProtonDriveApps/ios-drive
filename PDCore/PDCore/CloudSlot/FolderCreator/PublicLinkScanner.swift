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
import CoreData
import PDClient

class PublicLinkScanner {
    typealias ShareURLContext = ListShareURLEndpoint.Response.ShareURLContext

    private let client: Client
    private let storage: StorageManager

    init(
        client: Client,
        storage: StorageManager
    ) {
        self.client = client
        self.storage = storage
    }

    public func scanAllShareURL(volumeID: String) async throws {
        let supportedSharesValidator = makeSupportedSharesValidator()
        try await fetchShareURLs(volumeID, atPage: 0, validator: supportedSharesValidator)
    }

    private func fetchShareURLs(_ volumeID: String, atPage page: Int, validator: SupportedSharesValidator) async throws {
        let context = storage.backgroundContext
        let pageSize = Constants.pageSizeForChildrenFetchAndEnumeration
        let response = try await client.getShareUrl(volumeID: volumeID, page: page, pageSize: pageSize)
        Log.info("Fetched Trash – Page: \(page), Items: \(response)", domain: .networking)

        for contextShare in response.shareURLContexts {
            guard validator.isValid(contextShare.contextShareID),
                  !contextShare.linkIDs.isEmpty else {
                continue
            }

            try await fetchAllLinks(contextShare: contextShare, in: context)
        }

        guard response.more else { return }
        try await fetchShareURLs(volumeID, atPage: page + 1, validator: validator)
    }

    private func fetchAllLinks(contextShare: ShareURLContext, in context: NSManagedObjectContext) async throws {
        let shareID = contextShare.contextShareID
        let linkGroups = contextShare.linkIDs.splitInGroups(of: 150)

        var allSortedLinks: [Link] = []

        try await withThrowingTaskGroup(of: [Link].self) { group in
            for linkGroup in linkGroups {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    let linksResponse = try await self.client.getLinksMetadata(with: .init(shareId: shareID, linkIds: linkGroup))
                    return linksResponse.sortedLinks
                }
            }

            // Collect all results from the task group
            for try await result in group {
                allSortedLinks.append(contentsOf: result)
            }

            // Perform the save operation at the end, after all tasks have completed
            try context.performAndWait {
                self.storage.updateLinks(allSortedLinks, in: context)
                self.storage.updateShareURLs(contextShare.shareURLs, in: context)
                try context.saveOrRollback()
            }
        }
    }

    private func makeSupportedSharesValidator() -> SupportedSharesValidator {
        iOSSupportedSharesValidator(storage: storage)
    }
}
