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

enum SDKEnumerationStreamBridge {
    static func stream<Item: Sendable>(
        invoke: @escaping @Sendable (@escaping @Sendable (Result<Item, Error>) -> Void) async throws -> Void
    ) -> (stream: AsyncThrowingStream<Item, Error>, cancel: @Sendable () -> Void) {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Item.self)
        let finishGate = FinishGate()

        let sdkTask = Task {
            do {
                try await invoke { result in
                    switch result {
                    case .success(let item):
                        finishGate.performUnlessFinished {
                            continuation.yield(item)
                        }
                    case .failure(let error):
                        finishGate.finish {
                            continuation.finish(throwing: error)
                        }
                    }
                }
                finishGate.finish {
                    continuation.finish()
                }
            } catch {
                finishGate.finish {
                    continuation.finish(throwing: error)
                }
            }
        }

        let cancelBridgeTask: @Sendable () -> Void = {
            sdkTask.cancel()
        }

        continuation.onTermination = { @Sendable _ in
            sdkTask.cancel()
        }

        return (stream, cancelBridgeTask)
    }
}

private final class FinishGate: @unchecked Sendable {
    private var isFinished = false
    private let lock = NSLock()

    func performUnlessFinished(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        if isFinished { return }
        body()
    }

    func finish(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        if isFinished { return }
        isFinished = true
        body()
    }
}
