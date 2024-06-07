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
import PDCore

final class ThermalConstraintController: PhotoBackupConstraintController {
    private let resource: ThermalStateResource
    private let measurementRepository: DurationMeasurementRepository
    private let subject = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()

    var constraint: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    init(resource: ThermalStateResource, measurementRepository: DurationMeasurementRepository) {
        self.resource = resource
        self.measurementRepository = measurementRepository
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.state
            .map { state in
                Log.info("Changed thermal state to: \(state)", domain: .application)
                return state == .warning
            }
            .removeDuplicates()
            .sink { [weak self] isConstrained in
                self?.handleUpdate(isConstrained: isConstrained)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(isConstrained: Bool) {
        if isConstrained {
            measurementRepository.start()
        } else {
            measurementRepository.stop()
        }
        subject.send(isConstrained)
    }
}
