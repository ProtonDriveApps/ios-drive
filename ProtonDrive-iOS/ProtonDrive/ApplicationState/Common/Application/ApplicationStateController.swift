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

protocol ApplicationStateController {
    var state: AnyPublisher<ApplicationRunningState, Never> { get }
}

final class ConcreteApplicationStateController: ApplicationStateController {
    private let stateResource: ApplicationRunningStateResource
    private let subject = CurrentValueSubject<ApplicationRunningState, Never>(.foreground)
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<ApplicationRunningState, Never> {
        subject.eraseToAnyPublisher()
    }

    init(stateResource: ApplicationRunningStateResource) {
        self.stateResource = stateResource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        stateResource.state
            .sink { [weak self] state in
                self?.subject.send(state)
            }
            .store(in: &cancellables)
    }
}
