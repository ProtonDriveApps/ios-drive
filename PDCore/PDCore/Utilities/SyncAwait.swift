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

import Foundation

public enum SyncAwait {

    private final class Box<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: Result<T, Error>?

        func set(_ result: Result<T, Error>) {
            lock.lock()
            defer { lock.unlock() }
            storage = result
        }

        func take() -> Result<T, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    /// Core implementation shared by all blocking `run` variants.
    /// Returns `nil` only when `timeout != nil` and the wait timed out.
    private static func runDetached<T: Sendable>(
        timeout: DispatchTimeInterval?,
        priority: TaskPriority?,
        _ operation: @escaping @Sendable () async throws -> T
    ) throws -> T? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = Box<T>()
        Task.detached(priority: priority) {
            defer { semaphore.signal() }
            do {
                let value = try await operation()
                box.set(.success(value))
            } catch {
                box.set(.failure(error))
            }
        }
        if let timeout {
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                return nil
            }
        } else {
            semaphore.wait()
        }
        switch box.take() {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            fatalError("SyncAwait: semaphore signaled with no result stored")
        }
    }

    /// Run `operation` to completion on a detached Task, blocking the current thread.
    /// Rethrows any error from `operation`. Must not be called from the main thread.
    public static func run<T: Sendable>(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async throws -> T
    ) throws -> T {
        assert(!Thread.isMainThread)
        guard let value = try runDetached(timeout: nil, priority: priority, operation) else {
            fatalError("SyncAwait.run: runDetached returned nil with no timeout")
        }
        return value
    }

    /// Run `operation` with a timeout. Returns nil if the timeout elapses first.
    /// The detached task is NOT cancelled on timeout; it keeps running in the background.
    public static func run<T: Sendable>(
        timeout: DispatchTimeInterval,
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async throws -> T
    ) throws -> T? {
        try runDetached(timeout: timeout, priority: priority, operation)
    }

    /// Void overload that reports timeout as Bool instead of forcing `Void?` ergonomics.
    @discardableResult
    public static func run(
        timeout: DispatchTimeInterval,
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async -> Void
    ) -> Bool {
        do {
            let result: Void? = try runDetached(timeout: timeout, priority: priority) {
                await operation()
            }
            return result != nil
        } catch {
            fatalError("SyncAwait.run(timeout:): non-throwing operation produced an error: \(error)")
        }
    }
}

private extension DispatchTimeInterval {
    var seconds: TimeInterval {
        switch self {
        case .seconds(let s): return TimeInterval(s)
        case .milliseconds(let ms): return TimeInterval(ms) / 1_000
        case .microseconds(let us): return TimeInterval(us) / 1_000_000
        case .nanoseconds(let ns): return TimeInterval(ns) / 1_000_000_000
        case .never: return .infinity
        @unknown default: return .infinity
        }
    }
}
