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

public final class TrashScanner {
    private let client: Client
    private let storage: StorageManager
    private let myVolume: String

    init(client: Client, storage: StorageManager, myVolume: String) {
        self.client = client
        self.storage = storage
        self.myVolume = myVolume
    }

    public func scanTrash() async throws {
        try await scanAllTrashed(volumeID: myVolume)
    }

    public func scanAllTrashed(volumeID: String) async throws {
        let supportedSharesValidator = makeSupportedSharesValidator()
        try await fetchTrashMyVolume(volumeID, atPage: 0, validator: supportedSharesValidator)
    }

    // Does not support Device volumes
    private func fetchTrashMyVolume(_ volumeID: String, atPage page: Int, validator: SupportedSharesValidator) async throws {
        let pageSize = Constants.pageSizeForChildrenFetchAndEnumeration
        let response = try await client.listVolumeTrash(volumeID: volumeID, page: page, pageSize: pageSize)

        for batch in response.trash {
            guard validator.isValid(batch.shareID),
                  !batch.linkIDs.isEmpty else {
                continue
            }

            let linksResponse = try await client.getLinksMetadata(with: .init(shareId: batch.shareID, linkIds: batch.linkIDs))

            let context = storage.backgroundContext

            try await context.perform { [weak self] in
                guard let self else { return }
                self.storage.updateLinks(linksResponse.sortedLinks, in: context)
                try context.saveOrRollback()
            }
        }

        guard !isLastPage(response) else { return }
        try await fetchTrashMyVolume(volumeID, atPage: page + 1, validator: validator)
    }

    private func isLastPage(_ response: ListVolumeTrashEndpoint.Response) -> Bool {
        // BE sends either empty array, or entries with empty linkIDs
        return response.trash.isEmpty || response.trash.flatMap(\.linkIDs).isEmpty
    }

    private func makeSupportedSharesValidator() -> SupportedSharesValidator {
        iOSSupportedSharesValidator(storage: storage)
    }
}
