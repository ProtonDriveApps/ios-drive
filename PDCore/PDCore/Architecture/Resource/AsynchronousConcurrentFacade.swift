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
import Foundation

/// Non-blocking facade used for invoking on background queue and returning result on main again. Only one task at a time.
open class AsynchronousConcurrentFacade<I: AsynchronousInteractor, Input, Output> where Input == I.Input, I.Output == Output {
    private let interactor: I
    private let subject = PassthroughSubject<Output, Never>()
    private let queue = OperationQueue(maxConcurrentOperation: 1, isSuspended: false, underlyingQueue: DispatchQueue(label: "AsynchronousConcurrentFacade", qos: .default))

    public var result: AnyPublisher<Output, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(interactor: I) {
        self.interactor = interactor
    }

    public func execute(with input: Input) {
        let operation = AsynchronousBlockOperation { [weak self] in
            await self?.executeAsynchronously(with: input)
        }
        queue.addOperation(operation)
    }

    public func resume() {
        queue.isSuspended = false
    }

    public func suspend() {
        queue.isSuspended = true
    }

    private func executeAsynchronously(with input: Input) async {
        let output = await interactor.execute(with: input)
        await MainActor.run { [weak self] in
            self?.subject.send(output)
        }
    }
}
