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

import CoreData
import Foundation
import PDCore
import PDClient

protocol MetadataCache {
    func cache(links: [Link]) async throws
    func filterByCache(
        for identifiers: [AnyVolumeIdentifier]
    ) async -> [(AnyVolumeIdentifier, CoreDataMetadataCache.Result)]
}

final class CoreDataMetadataCache: MetadataCache {
    private let store: StorageManager
    private let context: NSManagedObjectContext

    init(store: StorageManager, context: NSManagedObjectContext) {
        self.store = store
        self.context = context
    }

    func cache(links: [Link]) async throws {
        try await context.perform { [weak self] in
            guard let self else { return }
            self.store.updateLinks(links, in: self.context)
            try self.context.saveOrRollback()
        }
    }

    func filterByCache(
        for identifiers: [AnyVolumeIdentifier]
    ) async -> [(AnyVolumeIdentifier, Result)] {
        await context.perform { [weak self] in
            guard let self else { return identifiers.map { ($0, .ignored) } }
            var result: [(AnyVolumeIdentifier, Result)] = []
            for identifier in identifiers {
                let node = Node.fetch(
                    id: identifier.id,
                    volumeID: identifier.volumeID,
                    allowSubclasses: true,
                    in: self.context
                )
                let cacheResult: Result = node == nil ? .remote : .fetched
                result.append((identifier, cacheResult))
            }
            return result
        }
    }

    enum Result {
        case ignored
        case remote
        case fetched
    }
}
