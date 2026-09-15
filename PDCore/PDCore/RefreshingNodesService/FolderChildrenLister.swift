// Copyright (c) 2026 Proton AG
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

/// Fetches one page of a folder's children link IDs. `Client` conforms; tests inject a mock.
protocol FolderChildrenListV2DataSource {
    func listFolderChildrenV2(
        volumeID: String,
        folderID: String,
        anchorID: String?,
        foldersOnly: Bool
    ) async throws -> FolderChildrenListV2Response
}

extension Client: FolderChildrenListV2DataSource {}

/// Lists all of a folder's children via the v2 listing endpoint, following pagination — it threads the
/// server's `AnchorID` from one page to the next until `more == false`. Each page request is retried on
/// transient failures. Pages are delivered to `onPage` as they arrive, so callers can persist them without
/// holding the whole listing in memory.
struct FolderChildrenLister {
    private let dataSource: FolderChildrenListV2DataSource
    private let retryConfiguration: HttpClientResilience.Configuration

    init(
        dataSource: FolderChildrenListV2DataSource,
        retryConfiguration: HttpClientResilience.Configuration = .forDriveAPICalls
    ) {
        self.dataSource = dataSource
        self.retryConfiguration = retryConfiguration
    }

    func listAllChildren(
        volumeID: String,
        folderID: String,
        foldersOnly: Bool,
        onPage: ([String]) async throws -> Void
    ) async throws {
        var anchorID: String?
        var seenAnchorIDs = Set<String>()
        while true {
            let currentAnchorID = anchorID
            let response = try await ScanRetry.perform(configuration: retryConfiguration) {
                try await dataSource.listFolderChildrenV2(
                    volumeID: volumeID,
                    folderID: folderID,
                    anchorID: currentAnchorID,
                    foldersOnly: foldersOnly
                )
            }
            if !response.linkIDs.isEmpty {
                try await onPage(response.linkIDs)
            }
            guard response.more else { break }
            // A page claiming more must advance to a new anchor; a missing or repeated anchor would loop
            // forever, so stop and abandon the rest of this folder's listing.
            guard let next = response.anchorID, seenAnchorIDs.insert(next).inserted else {
                Log.error("Sync v2: children listing anchor did not advance, stopping pagination", domain: .syncing)
                break
            }
            anchorID = next
        }
    }
}
