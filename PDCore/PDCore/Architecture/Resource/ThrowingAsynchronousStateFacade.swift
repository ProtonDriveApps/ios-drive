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

import Combine
import Foundation

/// Non-blocking facade used for invoking on background queue and posting state updates on main queue.
/// This is to abstract away from threading control polluting business logic code, allow testing, and create less error-prone api.
/// See example below
///
/// Old code:
/// ```
///     Task {
///         do {
///             try await worker.execute()
///         } catch { error in
///             MainActor.run {
///                 handleError()
///             }
///         }
///     }
///     worker.state
///         .receive(on: DispatchQueue.main)
///         .sink { }
/// ```
///
/// New code:
/// ```
///     worker.state
///         .sink { }
///     facade.execute()
/// ```
///
open class ThrowingAsynchronousStateFacade<I: ThrowingAsynchronousStateInteractor, Output> where I.Output == Output {
    private let interactor: I
    private let errorSubject = PassthroughSubject<Result<Output, Error>, Never>()

    public var state: AnyPublisher<Result<Output, Error>, Never> {
        Publishers.Merge(interactor.state, errorSubject)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    public init(interactor: I) {
        self.interactor = interactor
    }

    public func execute() {
        Task(priority: .low) {
            do {
                try await interactor.execute()
            } catch {
                errorSubject.send(.failure(error))
            }
        }
    }
}
