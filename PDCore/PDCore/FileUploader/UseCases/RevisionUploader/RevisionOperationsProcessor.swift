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

import Combine

final class RevisionOperationsProcessor {
    let serial: OperationIterator
    let concurrent: OperationIterator

    var didFinish: (() -> Void)?

    private var cancellable: AnyCancellable?

    private let serialQueue: OperationQueue
    private let concurrentQueue: OperationQueue
    private let maxConcurrentOperations: Int

    internal init(serial: OperationIterator, concurrent: OperationIterator, maxConcurrentOperations: Int = OperationQueue.defaultMaxConcurrentOperationCount) {
        self.serial = serial
        self.concurrent = concurrent
        self.maxConcurrentOperations = maxConcurrentOperations
        serialQueue = OperationQueue(maxConcurrentOperation: 1, underlyingQueue: DispatchQueue.global(qos: .userInitiated))
        concurrentQueue = OperationQueue(maxConcurrentOperation: maxConcurrentOperations, underlyingQueue: DispatchQueue.global(qos: .userInitiated))
    }

    func process() {
        subscribeToChangeInSerialQueue()
    }

    private func subscribeToChangeInSerialQueue() {
        cancellable = serialQueue.publisher(for: \.operations)
            .dropFirst()
            .filter { $0.isEmpty }
            .sink { [unowned self] _ in
                self.addNextSerialOperation()
            }
        addNextSerialOperation()
    }

    private func addNextSerialOperation() {
        if let op = serial.next() {
            serialQueue.addOperation(op)
        } else {
            subscribeToChangeInConcurrentQueue()
        }
    }

    private func subscribeToChangeInConcurrentQueue() {
        cancellable?.cancel()
        cancellable = nil

        cancellable = concurrentQueue.publisher(for: \.operations)
            .dropFirst()
            .sink { [unowned self] _ in
                self.addNextConcurrentOperation()
            }
        addNextConcurrentOperation()
    }

    private func addNextConcurrentOperation() {
        guard concurrentQueue.operations.count < maxConcurrentOperations else { return }

        if let concurrentOperation = concurrent.next() {
            concurrentQueue.addOperation(concurrentOperation)
        } else if concurrentQueue.operations.isEmpty {
            finishProcess()
        }
    }

    private func finishProcess() {
        cancellable?.cancel()
        cancellable = nil

        didFinish?()
    }
}
