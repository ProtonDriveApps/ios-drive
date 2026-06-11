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

/// A synchronous context pool for code paths that cannot use async/await.
///
/// Unlike `AsyncManagedObjectContextPool`, this pool:
/// - Has no maximum size limit - always returns a context
/// - Provides only acquire/relinquish API
/// - Uses traditional locking for thread safety
/// - Supports usage-based contexts with reference counting
///
/// Use this sparingly for legacy synchronous code paths (e.g., FileProvider callbacks).
/// Prefer `AsyncManagedObjectContextPool` for new async code.
public final class SyncManagedObjectContextPool: @unchecked Sendable {

    /// Predefined usage types for usage-based context acquisition.
    /// Contexts acquired with a usage are reference-counted and shared across all acquires with the same usage.
    public enum Usage: Hashable {
        case folderModel
        case activityModel
    }

    private let mergePolicy: NSMergePolicyType
    private let contextNamePrefix: String
    private let contextFactory: (NSMergePolicyType) -> NSManagedObjectContext

    private let lock = NSLock()
    private var availableContexts: [NSManagedObjectContext] = []
    private var createdCount: Int = 0

    /// Tracks contexts associated with specific usages along with their reference counts
    private var usageContexts: [Usage: (context: NSManagedObjectContext, refCount: Int)] = [:]

    public init(
        mergePolicy: NSMergePolicyType = .mergeByPropertyObjectTrumpMergePolicyType,
        contextNamePrefix: String = "SyncPooledContext",
        contextFactory: @escaping (NSMergePolicyType) -> NSManagedObjectContext
    ) {
        self.mergePolicy = mergePolicy
        self.contextNamePrefix = contextNamePrefix
        self.contextFactory = contextFactory
    }

    // MARK: - Standard Acquire/Relinquish

    /// Acquires a context from the pool, creating one if none available.
    /// The caller MUST call `relinquish(_:)` when done with the context.
    public func acquire() -> NSManagedObjectContext {
        lock.lock()
        defer { lock.unlock() }

        if let context = availableContexts.popLast() {
            return context
        }

        return createNewContext()
    }

    /// Releases a context back to the pool.
    /// The context is reset before being made available for reuse.
    public func relinquish(_ context: NSManagedObjectContext) {
        context.performAndWait {
            context.reset()
            context.resetCounter()
        }
        context.mergePolicy = NSMergePolicy(merge: mergePolicy)

        lock.lock()
        availableContexts.append(context)
        lock.unlock()
    }

    // MARK: - Usage-Based Acquire/Release

    /// Acquires a context for a specific usage.
    ///
    /// If a context already exists for this usage, returns the same context and increments the reference count.
    /// Otherwise, creates a new context for this usage.
    ///
    /// The caller MUST call `relinquish(for:)` with the same usage when done.
    /// The context is only reset when all users have released it (reference count reaches 0).
    public func acquire(for usage: Usage) -> NSManagedObjectContext {
        lock.lock()
        defer { lock.unlock() }

        if let existing = usageContexts[usage] {
            usageContexts[usage] = (existing.context, existing.refCount + 1)
            return existing.context
        }

        let context = createNewContext(suffix: "-\(usage)")
        usageContexts[usage] = (context, 1)
        return context
    }

    /// Relinquishes a context for a specific usage.
    ///
    /// Decrements the reference count for the usage. When the count reaches 0,
    /// the context is reset but kept alive for reuse on the next acquire.
    public func relinquish(for usage: Usage) {
        lock.lock()
        defer { lock.unlock() }

        guard let existing = usageContexts[usage] else {
            assertionFailure("Releasing context for usage \(usage) that was never acquired")
            return
        }

        let newRefCount = existing.refCount - 1

        if newRefCount > 0 {
            usageContexts[usage] = (existing.context, newRefCount)
        } else {
            usageContexts[usage] = (existing.context, 0)
            existing.context.performAndWait {
                existing.context.reset()
                existing.context.resetCounter()
            }
            existing.context.mergePolicy = NSMergePolicy(merge: mergePolicy)
        }
    }

    // MARK: - Private

    private func createNewContext(suffix: String = "") -> NSManagedObjectContext {
        let context = contextFactory(mergePolicy)
        context.name = "\(contextNamePrefix)-\(createdCount)\(suffix)"
        createdCount += 1
        return context
    }

    // MARK: - Testing Support

    #if DEBUG
    /// Number of contexts currently available in the pool
    public var availableCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return availableContexts.count
    }

    /// Total number of contexts created so far
    public var totalCreatedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return createdCount
    }

    /// Returns the current reference count for a usage, or nil if no context exists for that usage
    public func referenceCount(for usage: Usage) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return usageContexts[usage]?.refCount
    }

    /// Returns true if a context exists for the given usage (including idle contexts with refCount 0)
    public func hasContext(for usage: Usage) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return usageContexts[usage] != nil
    }

    /// Returns true if a context exists for the given usage and is actively being used (refCount > 0)
    public func isContextActive(for usage: Usage) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return (usageContexts[usage]?.refCount ?? 0) > 0
    }
    #endif
}
