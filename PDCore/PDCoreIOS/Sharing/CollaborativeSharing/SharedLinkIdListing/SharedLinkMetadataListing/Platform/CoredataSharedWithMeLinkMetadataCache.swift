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
import PDCore
import CoreData
import PDClient

public class CoredataSharedWithMeLinkMetadataCache: SharedWithMeMetadataCache {
    private let storage: StorageManager

    public init(storage: StorageManager) {
        self.storage = storage
    }

    public func cache(_ link: PDClient.Link, _ share: GetShareBootstrapEndpoint.BootstrapedShareResponse) async throws {
        let context = storage.backgroundContext

        try context.performAndWait {
            do {
                storage.updateShare(share, in: context)
                let node = storage.updateLink(link, fetchingSharedWithMeRoot: true, using: context)
                node.isSharedWithMeRoot = true
                try context.saveOrRollback()
            } catch {
                Log.error(error: error, domain: .storage)
                throw error
            }
        }
    }
}
