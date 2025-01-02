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
import Photos
import PDCore

enum PhotoLibraryFetchResourceError: Error {
    case missingMapping
}

final class LocalPhotoLibraryFetchResource: PhotoLibraryIdentifiersResource {
    private let identifiersRepository: PhotoLibraryIdentifiersRepository
    private let measurementRepository: DurationMeasurementRepository
    private let updateSubject = PassthroughSubject<PhotoIdentifiers, Never>()
    private let queue = OperationQueue(underlyingQueue: DispatchQueue(label: "LocalPhotoLibraryFetchResource", qos: .default, attributes: .concurrent))

    var updatePublisher: AnyPublisher<PhotoLibraryLoadUpdate, Never> {
        updateSubject
            .map { PhotoLibraryLoadUpdate.fullLoad($0) }
            .eraseToAnyPublisher()
    }

    init(identifiersRepository: PhotoLibraryIdentifiersRepository, measurementRepository: DurationMeasurementRepository) {
        self.identifiersRepository = identifiersRepository
        self.measurementRepository = measurementRepository
    }

    func execute() {
        cancel()
        let operation = AsynchronousBlockOperation { [weak self] in
            self?.measurementRepository.start()
            let identifiers = (await self?.identifiersRepository.getIdentifiers()) ?? []
            await MainActor.run { [weak self] in
                self?.updateSubject.send(identifiers)
                self?.measurementRepository.stop()
            }
        }
        queue.addOperation(operation)
    }

    func cancel() {
        queue.cancelAllOperations()
    }

    func suspend() {
        queue.isSuspended = true
    }

    func resume() {
        queue.isSuspended = false
    }
}
