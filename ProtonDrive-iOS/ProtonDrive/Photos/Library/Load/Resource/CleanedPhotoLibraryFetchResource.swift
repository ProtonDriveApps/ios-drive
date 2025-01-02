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

import Foundation
import PDCore
import Combine
import Photos

final class CleanedPhotoLibraryFetchResource: PhotoLibraryIdentifiersResource {
    private let cleanedUploadingStore: DeletedPhotosIdentifierStoreResource
    private let identifiersRepository: PhotoLibraryIdentifiersRepository
    private let measurementRepository: DurationMeasurementRepository
    private let updateSubject = PassthroughSubject<PhotoLibraryLoadUpdate, Never>()
    private let cleanedPhotosRetryEvent: AnyPublisher<Void, Never>
    private var cancellable: AnyCancellable?
    private let queue = OperationQueue(underlyingQueue: DispatchQueue(label: "CleanedPhotoLibraryFetchResource", qos: .userInitiated, attributes: .concurrent))

    var updatePublisher: AnyPublisher<PhotoLibraryLoadUpdate, Never> {
        updateSubject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(
        cleanedUploadingStore: DeletedPhotosIdentifierStoreResource,
        cleanedPhotosRetryEvent: AnyPublisher<Void, Never>,
        identifiersRepository: PhotoLibraryIdentifiersRepository,
        measurementRepository: DurationMeasurementRepository
    ) {
        self.cleanedUploadingStore = cleanedUploadingStore
        self.cleanedPhotosRetryEvent = cleanedPhotosRetryEvent
        self.identifiersRepository = identifiersRepository
        self.measurementRepository = measurementRepository
    }
    
    func execute() {
        cancel()
        cancellable = cleanedPhotosRetryEvent
            .delay(for: .milliseconds(200), scheduler: queue) // Adding small delay to avoid state race conditions
            .sink { [weak self] in
                guard let self = self else { return }
                self.updateSubject.send(.loading)
                self.processCleanedPhotos()
            }
    }
    
    func cancel() {
        queue.cancelAllOperations()
        cancellable?.cancel()
        cancellable = nil
    }

    func suspend() {
        queue.isSuspended = true
    }

    func resume() {
        queue.isSuspended = false
    }

    private func processCleanedPhotos() {
        Task { [weak self] in
            guard let self else { return }
            Log.info("Processing failed items: \(self.cleanedUploadingStore.getCount())", domain: .photosProcessing)
            self.measurementRepository.start()
            self.cleanedUploadingStore.reset()
            let identifiers = await self.identifiersRepository.getIdentifiers()
            self.updateSubject.send(.fullLoad(identifiers))
            self.measurementRepository.stop()
        }
    }
}
