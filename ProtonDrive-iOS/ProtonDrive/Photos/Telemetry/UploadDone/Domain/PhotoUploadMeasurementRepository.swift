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

import PDCore

final class ConcretePhotoUploadMeasurementRepository: PhotoUploadMeasurementRepository {
    private var storage: PhotoUploadMeasurementsStorage
    private let durationRepository: DurationMeasurementRepository
    private let notifier: PhotoUploadDoneNotifier
    private let identifier: String

    init(identifier: String, storage: PhotoUploadMeasurementsStorage, durationRepository: DurationMeasurementRepository, notifier: PhotoUploadDoneNotifier) {
        self.identifier = identifier
        self.storage = storage
        self.durationRepository = durationRepository
        self.notifier = notifier
    }

    func resume() {
        durationRepository.start()
    }

    func pause() {
        durationRepository.stop()
        storage[identifier] = getCombinedDuration()
        durationRepository.reset()
    }

    func succeed(with kilobytes: Double) {
        finish(isSuccess: true, kilobytes: kilobytes)
        storage[identifier] = nil
    }

    func fail(with kilobytes: Double) {
        finish(isSuccess: false, kilobytes: kilobytes)
        storage[identifier] = nil
    }

    private func getCombinedDuration() -> Double {
        return (storage[identifier] ?? 0) + durationRepository.get()
    }

    private func finish(isSuccess: Bool, kilobytes: Double) {
        durationRepository.stop()
        let duration = getCombinedDuration()
        let data = PhotoUploadDoneData(isSuccess: isSuccess, kilobytes: kilobytes, duration: duration)
        notifier.notify(data)
    }
}
