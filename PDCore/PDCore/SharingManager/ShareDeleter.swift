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

public protocol ShareDeleter {
    func deleteShare(_ id: String, force: Bool) async throws
}

public final class RemoteCachingShareDeleter: ShareDeleter {
    private let client: Client
    private let storage: StorageManager
    
    public init(client: Client, storage: StorageManager) {
        self.client = client
        self.storage = storage
    }
    
    public func deleteShare(_ id: String, force: Bool) async throws {
        try await self.client.deleteShare(id: id, force: force)

        let context = storage.backgroundContext
        try await context.perform {
            guard let share = Share.fetch(id: id, in: context) else { return }
            share.shareUrls.forEach(context.delete)
            context.delete(share)
            try context.saveOrRollback()
        }
    }
}
