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

final class ReentrantDurationMeasurementRepositoryDecorator: DurationMeasurementRepository {
    private let queue = DispatchQueue(label: "PDCore.ReentrantPhotosBackupUpdateValueRepository.\(UUID().uuidString)")
    private let repository: DurationMeasurementRepository

    init(repository: DurationMeasurementRepository) {
        self.repository = repository
    }

    func start() {
        queue.sync {
            repository.start()
        }
    }

    func stop() {
        queue.sync {
            repository.stop()
        }
    }

    func get() -> Double {
        return queue.sync {
            return repository.get()
        }
    }

    func reset() {
        queue.sync {
            repository.reset()
        }
    }
}
