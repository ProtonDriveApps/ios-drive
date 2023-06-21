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

/// Non-blocking facade used for invoking on main queue and returning result on main again.
open class AsynchronousFacade<I: Interactor, Input, Output> where Input == I.Input, I.Output == Output {
    private let interactor: I
    private let subject = PassthroughSubject<Result<Output, Error>, Never>()

    public var result: AnyPublisher<Result<Output, Error>, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(interactor: I) {
        self.interactor = interactor
    }

    public func execute(with input: Input) {
        Task {
            do {
                let output = try await interactor.execute(with: input)
                await finish(with: .success(output))
            } catch {
                await finish(with: .failure(error))
            }
        }
    }

    @MainActor
    private func finish(with result: Result<Output, Error>) {
        subject.send(result)
    }
}
