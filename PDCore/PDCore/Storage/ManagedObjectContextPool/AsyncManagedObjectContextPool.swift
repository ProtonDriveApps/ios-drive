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

/// A pool that maintains reusable NSManagedObjectContext instances with lazy creation.
/// Contexts are created on-demand up to a maximum pool size.
/// Contexts are checked out for use and returned when operations complete.
public actor AsyncManagedObjectContextPool {

    public struct Configuration: Sendable {
        /// Maximum number of contexts in the pool
        public let maxPoolSize: Int
        /// Default merge policy for contexts
        public let mergePolicy: NSMergePolicyType
        /// Prefix for context names (contexts will be named "{prefix}-0", "{prefix}-1", etc.)
        public let contextNamePrefix: String

        public static let `default` = Configuration(
            maxPoolSize: 32,
            mergePolicy: .mergeByPropertyObjectTrumpMergePolicyType,
            contextNamePrefix: "PooledContext"
        )

        public init(maxPoolSize: Int, mergePolicy: NSMergePolicyType, contextNamePrefix: String = "PooledContext") {
            self.maxPoolSize = maxPoolSize
            self.mergePolicy = mergePolicy
            self.contextNamePrefix = contextNamePrefix
        }
    }

    private let configuration: Configuration
    private let contextFactory: @Sendable (NSMergePolicyType) -> NSManagedObjectContext

    /// Available contexts ready for use
    private var availableContexts: [NSManagedObjectContext] = []
    /// Total number of contexts created (available + in use)
    private var createdCount: Int = 0
    /// Number of contexts currently in use
    private var inUseCount: Int = 0
    /// Continuations waiting for a context to become available
    private var waiters: [CheckedContinuation<NSManagedObjectContext, Never>] = []

    public init(
        configuration: Configuration = .default,
        contextFactory: @Sendable @escaping (NSMergePolicyType) -> NSManagedObjectContext
    ) {
        self.configuration = configuration
        self.contextFactory = contextFactory
    }

    /// Acquires a context from the pool, executes the operation, and returns the context.
    /// The operation receives the context but is not automatically performed on the context's queue.
    /// Use `performInContext` if you need the operation to run on the context's queue.
    public func withContext<T: Sendable>(
        mergePolicy: NSMergePolicyType? = nil,
        _ operation: (NSManagedObjectContext) async throws -> T
    ) async rethrows -> T {
        let context = await acquireContext(mergePolicy: mergePolicy)
        do {
            let result = try await operation(context)
            if let managedObject = result as? NSManagedObject, managedObject.moc === context {
                assertionFailure("Returned object is invalid, its MOC has been reset. Do not use it.")
            }
            await relinquishContext(context)
            return result
        } catch {
            await relinquishContext(context)
            throw error
        }
    }

    /// Acquires a context from the pool, executes the operation on the context's queue, and releases the context.
    /// The operation is performed using `context.perform`, ensuring thread safety for Core Data operations.
    public func performInContext<T: Sendable>(
        mergePolicy: NSMergePolicyType? = nil,
        _ operation: @Sendable @escaping (NSManagedObjectContext) throws -> T
    ) async rethrows -> T {
        let context = await acquireContext(mergePolicy: mergePolicy)
        do {
            let result = try await context.perform {
                try operation(context)
            }
            if let managedObject = result as? NSManagedObject, managedObject.moc === context {
                assertionFailure("Returned object is invalid, its MOC has been reset. Do not use it.")
            }
            await relinquishContext(context)
            return result
        } catch {
            await relinquishContext(context)
            throw error
        }
    }

    private func acquireContext(
        mergePolicy: NSMergePolicyType? = nil
    ) async -> NSManagedObjectContext {
        let context: NSManagedObjectContext

        if let availableContext = availableContexts.popLast() {
            // Reuse an available context
            context = availableContext
        } else if createdCount < configuration.maxPoolSize {
            // Create a new context lazily (we haven't reached the maximum yet)
            context = createNewContext()
        } else {
            // Pool exhausted - log and wait for a context to be released
            Log.info("AsyncManagedObjectContextPool exhausted, waiting for available context. In use: \(inUseCount)/\(configuration.maxPoolSize), waiters: \(waiters.count + 1)", domain: .storage)

            context = await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        inUseCount += 1

        // Apply custom merge policy if specified
        if let mergePolicy {
            context.mergePolicy = NSMergePolicy(merge: mergePolicy)
        }

        return context
    }

    private func createNewContext() -> NSManagedObjectContext {
        let context = contextFactory(configuration.mergePolicy)
        context.name = "\(configuration.contextNamePrefix)-\(createdCount)"
        createdCount += 1
        return context
    }

    private func relinquishContext(_ context: NSManagedObjectContext) async {
        inUseCount -= 1

        // Reset context state for reuse - releases memory from managed objects
        // Must be performed on the context's queue
        await context.perform {
            context.reset()
            context.resetCounter()
        }
        context.mergePolicy = NSMergePolicy(merge: configuration.mergePolicy)

        if let waiter = waiters.first {
            // Hand context directly to a waiter
            waiters.removeFirst()
            waiter.resume(returning: context)
        } else {
            // Return to available pool
            availableContexts.append(context)
        }
    }
    
    deinit {
        // prevents the endless waiting for continuation
        waiters.forEach {
            let context = availableContexts.popLast() ?? contextFactory(configuration.mergePolicy)
            $0.resume(returning: context)
        }
    }

    // MARK: - Testing Support

    #if DEBUG
    /// Number of contexts currently available in the pool
    public var availableCount: Int {
        availableContexts.count
    }

    /// Number of contexts currently in use
    public var currentInUseCount: Int {
        inUseCount
    }

    /// Total number of contexts created so far (available + in use)
    public var totalCreatedCount: Int {
        createdCount
    }

    /// Number of operations waiting for a context
    public var waitingCount: Int {
        waiters.count
    }

    /// Names of all available contexts
    public var availableContextNames: [String] {
        availableContexts.compactMap(\.name)
    }

    /// Checks if a context with the given name is currently available in the pool
    public func isContextAvailable(named name: String) -> Bool {
        availableContexts.contains { $0.name == name }
    }
    #endif
}
