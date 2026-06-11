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
import CoreData
import PDCore

public protocol InvalidNodesDeleterProtocol {
    func deleteIfNeeded(identifiers: [AnyVolumeIdentifier], errorCode: Int) async throws
}

public final class InvalidNodesDeleter: InvalidNodesDeleterProtocol {
    let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public func deleteIfNeeded(identifiers: [AnyVolumeIdentifier], errorCode: Int) async throws {
        let noExisting = 2501
        guard errorCode == noExisting else { return }
        try await context.perform { [context] in
            let nodes = Node.fetch(identifiers: Set(identifiers), allowSubclasses: true, in: context)
            nodes.forEach { context.delete($0) }
            try context.saveIfNeeded()
        }
    }
}
