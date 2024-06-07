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
import PDCore

class ComputationalAvailabilityControllerFeederEnabledAdapter {
    private let controller: ComputationalAvailabilityController

    init(_ controller: ComputationalAvailabilityController) {
        self.controller = controller
    }

    var isFeederEnabled: AnyPublisher<Bool, Never> {
        controller.availability
            .handleEvents(receiveOutput: {
                Log.info("App state: \($0)", domain: .backgroundTask)
            })
            .map { $0 == .foreground || $0 == .processingTask }
            .handleEvents(receiveOutput: {
                Log.info("Can feed: \($0)", domain: .backgroundTask)
            })
            .eraseToAnyPublisher()
    }
}
