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

import Foundation

struct DebouncedBatchBufferConfiguration: Sendable {
    var maxBatchSize: Int
    var flushWindow: Duration

    static let nodeOperationFlush = DebouncedBatchBufferConfiguration(
        maxBatchSize: 450, // API batch limit is 150, but since this is local processing, a larger value is acceptable
        flushWindow: .milliseconds(300)
    )
}

/// Coalesces items and flushes when `maxBatchSize` is reached or after `flushWindow` from the first buffered item.
///
/// Scheduling behavior:
/// - The first pending item starts a flush timer.
/// - When the buffer reaches the maximum batch size, it flushes immediately.
/// - Calling `finish()` drains any remaining items.
actor DebouncedBatchBuffer<Element: Sendable> {

    private enum FlushTrigger: Sendable {
        case none
        case flushNow
    }

    private var buffer: [Element] = []
    private var hasOverflowRemainder = false
    private var flushTask: Task<Void, Never>?
    private var isFlushing = false
    private var flushWaiters: [CheckedContinuation<Void, Never>] = []
    private let configuration: DebouncedBatchBufferConfiguration
    private let onFlush: @Sendable ([Element]) async -> Void

    init(
        configuration: DebouncedBatchBufferConfiguration,
        onFlush: @escaping @Sendable ([Element]) async -> Void
    ) {
        self.configuration = configuration
        self.onFlush = onFlush
    }

    func append(_ element: Element) async {
        buffer.append(element)
        if buffer.count >= configuration.maxBatchSize {
            await performFlush()
            return
        }
        if buffer.count == 1 {
            scheduleFlush()
        }
    }

    func finish() async {
        flushTask?.cancel()
        flushTask = nil
        await performFlush()
    }

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task {
            do {
                try await Task.sleep(for: configuration.flushWindow)
            } catch {
                return
            }
            await performFlush()
        }
    }

    private func performFlush() async {
        if isFlushing {
            await withCheckedContinuation { continuation in
                flushWaiters.append(continuation)
            }
            if buffer.isEmpty { return }
        }

        isFlushing = true
        defer {
            isFlushing = false
            let waiters = flushWaiters
            flushWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        flushTask?.cancel()
        flushTask = nil

        repeat {
            let batch = takeBatch()
            guard !batch.isEmpty else { break }
            await onFlush(batch)
        } while overflowFlushTrigger() == .flushNow

        if !buffer.isEmpty {
            scheduleFlush()
        }
    }

    private func takeBatch() -> [Element] {
        let count = min(buffer.count, configuration.maxBatchSize)
        guard count > 0 else { return [] }
        let batch = Array(buffer.prefix(count))
        buffer.removeFirst(count)
        if buffer.isEmpty {
            hasOverflowRemainder = false
        } else if count == configuration.maxBatchSize {
            hasOverflowRemainder = true
        }
        return batch
    }

    private func overflowFlushTrigger() -> FlushTrigger {
        guard !buffer.isEmpty else { return .none }
        if hasOverflowRemainder {
            return .flushNow
        }
        if buffer.count >= configuration.maxBatchSize {
            return .flushNow
        }
        return .none
    }
}

