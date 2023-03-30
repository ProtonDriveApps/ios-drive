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

final class PopulateViewModel: LogoutRequesting {
    public let populatedPublisher: AnyPublisher<PopulatedState, Never>

    private let populatedSubject: CurrentValueSubject<PopulatedState, Never>
    private let populator: DrivePopulator
    private let eventsStarter: EventsSystemStarter

    public init(
        populator: DrivePopulator,
        eventsStarter: EventsSystemStarter
    ) {
        let subject: CurrentValueSubject<PopulatedState, Never> = CurrentValueSubject(populator.state)

        self.populator = populator
        self.eventsStarter = eventsStarter
        self.populatedSubject = subject
        self.populatedPublisher = subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func populate() {
        populator.populate { [weak self] result in
            if let self {
                switch result {
                case .success:
                    self.populatedSubject.send(self.populator.state)
                    
                case .failure:
                    self.requestLogout()
                }
            }
        }
    }

    public func startEventsSystem() {
        eventsStarter.startEventsSystem()
    }
}
