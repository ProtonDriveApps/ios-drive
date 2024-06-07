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

final class AggregatingTelemetrySendEventDecorator: TelemetrySendEventInteractor {
    private let interactor: TelemetrySendEventsInteractor
    private var subject = PassthroughSubject<TelemetryData, Never>()
    private let queue = DispatchQueue(label: "ThrottlingTelemetryAggregationFacade", qos: .default)
    private var cancellables = Set<AnyCancellable>()

    init(interactor: TelemetrySendEventsInteractor) {
        self.interactor = interactor
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        subject
            .collect(.byTimeOrCount(queue, .seconds(60), 100)) // Will send only once per minute or if 100 events are gathered
            .sink { [weak self] array in
                self?.interactor.execute(events: array)
            }
            .store(in: &cancellables)
    }

    func execute(data: TelemetryData) {
        subject.send(data)
    }
}
