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
import Combine
import PDCore
import ProtonCoreNetworking

protocol CircuitBreakerController: ConstraintController {
    func handleError(_ error: Error)
}

class ReactiveCircuitBreakerController: CircuitBreakerController {
    private var errorSubject = PassthroughSubject<Error, Never>()
    private var enablePublisher: AnyPublisher<Bool, Never>

    var constraint: AnyPublisher<Bool, Never> {
        enablePublisher
    }

    init() {
        // Immediately switch to false on error, then debounce to switch back to true
        let errorToTrue = errorSubject
            .map { _ in true }
            .prepend(false) // Start with the circuit breaker enabled == no constraint

        let resetToFalse = errorSubject
            .debounce(for: .seconds(60), scheduler: RunLoop.main)
            .map { _ in false }

        // Merge the two publishers, ensuring immediate disable and delayed re-enable
        enablePublisher = Publishers.Merge(errorToTrue, resetToFalse)
            .removeDuplicates() // Prevent consecutive duplicate values
            .handleEvents(receiveOutput: { Log.info("🏎️ Circuit Breaker is now \($0 ? "constrained" : "enabled")", domain: .photosProcessing) })
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func handleError(_ error: Error) {
        if let errorCode = (error as? ResponseError)?.httpCode, RetryPolicy.retryable5xxErrors.contains(errorCode) {
            errorSubject.send(error)
        }
    }
}
