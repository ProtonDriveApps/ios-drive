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

// TODO: Route EnumeratorWithChanges.report(for:) through enqueueWrite once the DM-897 branch has
// landed. It is the last direct SyncItem writer still using a raw Task; deferred here only to keep
// EnumeratorWithChanges.swift conflict-free with that in-flight branch.

import Foundation

public extension SyncStorageManager {

    /// Serializes writes for a given `SyncItem` id. Operations enqueued for the same id run in the
    /// order they were enqueued; operations for different ids run concurrently. This guarantees the
    /// row converges to the last enqueued write regardless of task scheduling.
    func enqueueWrite(for id: String, _ operation: @escaping @Sendable () async -> Void) {
        writeChainLock.lock()
        defer { writeChainLock.unlock() }
        let previous = writeChains[id]
        let token = UUID()
        writeChainTokens[id] = token
        writeChains[id] = Task {
            await previous?.value
            await operation()
            self.completeWrite(for: id, token: token)
        }
    }

    /// Drops the chain entry for `id` once its last enqueued operation drains, bounding memory.
    /// A token mismatch means a newer write was enqueued meanwhile, so the entry is left in place.
    private func completeWrite(for id: String, token: UUID) {
        writeChainLock.lock()
        defer { writeChainLock.unlock() }
        guard writeChainTokens[id] == token else { return }
        writeChains[id] = nil
        writeChainTokens[id] = nil
    }
}

#if DEBUG
public extension SyncStorageManager {

    /// Awaits all currently enqueued write chains. Test-only.
    func drainWriteChains() async {
        let tasks = activeWriteTasks
        for task in tasks {
            await task.value
        }
    }
    
    var activeWriteTasks: [Task<Void, Never>] {
        writeChainLock.lock()
        defer { writeChainLock.unlock() }
        return Array(writeChains.values)
    }

    /// Number of active per-id write chains. Test-only.
    var activeWriteChainCount: Int {
        writeChainLock.lock()
        
        return writeChains.count
    }
}
#endif
