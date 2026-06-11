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

import Combine
import PDCore
import PDUIComponents

final class OfflineSaversProgressProvider: ProgressFractionCompletedProvider {
    private let offlineSavers: [OfflineSaverProtocol]
    private var states = CurrentValueSubject<[Int: OfflineSaverState], Never>([:])
    private var cancellables = Set<AnyCancellable>()

    var progressState: AnyPublisher<ProgressState, Never> {
        states
            .map { fractions in
                if fractions.isEmpty { return .inactive }
                let validFractions = fractions.compactMap { $0.value.value }
                if validFractions.isEmpty { return .inactive }
                let progress = validFractions.reduce(0, +) / Double(validFractions.count)
                return .progress(progress)
            }
            .eraseToAnyPublisher()
    }

    init(offlineSavers: [OfflineSaverProtocol]) {
        self.offlineSavers = offlineSavers
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        offlineSavers.enumerated().forEach { index, offlineSaver in
            offlineSaver.state
                .sink { [weak self] state in
                    guard let self else { return }

                    var value = self.states.value
                    value[index] = state
                    self.states.send(value)
                }
                .store(in: &cancellables)
        }
    }
}
