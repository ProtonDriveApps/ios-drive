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
import PDCore

protocol PhotosTelemetryUpsellControllerProtocol {}

final class PhotosTelemetryUpsellController: PhotosTelemetryUpsellControllerProtocol {
    let telemetryController: TelemetryController
    let notifier: PhotoUpsellResultNotifierProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(telemetryController: TelemetryController, notifier: PhotoUpsellResultNotifierProtocol) {
        self.telemetryController = telemetryController
        self.notifier = notifier
        subscribeUpdate()
    }
    
    private func subscribeUpdate() {
        notifier.data
            .sink { [weak self] result in
                self?.handle(result: result)
            }
            .store(in: &cancellables)
    }
    
    private func handle(result: PhotoUpsellResult) {
        telemetryController.send(data: result.makeData())
    }
}
