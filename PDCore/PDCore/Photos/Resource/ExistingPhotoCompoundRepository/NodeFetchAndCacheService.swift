// Copyright (c) 2023 Proton AG
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
import CoreData

public protocol NodeFetchAndCacheService {
    func fetchAndCache(_ id: NodeIdentifier) async throws
}

public class ClientNodeFetchAndCacheService: NodeFetchAndCacheService {
    private let client: Client
    private let cacher: CloudSlotProtocol
    private let context: NSManagedObjectContext

    public init(client: Client, cacher: CloudSlotProtocol, context: NSManagedObjectContext) {
        self.client = client
        self.cacher = cacher
        self.context = context
    }
    
    public func fetchAndCache(_ id: NodeIdentifier) async throws {
        let link = try await client.getLink(shareID: id.shareID, linkID: id.nodeID, breadcrumbs: .startCollecting())
        try await context.perform {
            try self.cacher.update(links: [link], shareId: id.shareID, managedObjectContext: self.context)
            try self.context.saveOrRollback()
        }
    }
}
