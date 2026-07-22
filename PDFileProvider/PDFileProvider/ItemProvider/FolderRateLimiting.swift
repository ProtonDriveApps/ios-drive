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

import CoreData
import Foundation
import PDCore

/// Wraps an operation against a folder so that repeated backend rejections
/// (TOO_MANY_CHILDREN / NESTING_TOO_DEEP) back off instead of busy-failing.
public protocol FolderRateLimiting: Sendable {
    func runOperation<T>(
        parent: NodeIdentifier,
        in moc: NSManagedObjectContext,
        _ operation: () async throws -> T
    ) async throws -> T
}

/// Pass-through implementation for sites without a real limiter (iOS, tests).
public struct NoOpFolderRateLimiter: FolderRateLimiting {
    public init() {}

    public func runOperation<T>(
        parent _: NodeIdentifier,
        in _: NSManagedObjectContext,
        _ operation: () async throws -> T
    ) async throws -> T {
        try await operation()
    }
}
