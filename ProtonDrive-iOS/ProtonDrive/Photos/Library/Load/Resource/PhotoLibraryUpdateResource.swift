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

final class LocalPhotoLibraryUpdateResource: NSObject, PhotoLibraryIdentifiersResource, PHPhotoLibraryChangeObserver {
    private let updateSubject = PassthroughSubject<PhotoIdentifiers, Never>()
    private let mappingResource: PhotoLibraryMappingResource
    private let optionsFactory: PHFetchOptionsFactory
    private let queueRepository: PhotoLibraryIdentifiersQueueRepository
    private let measurementRepository: DurationMeasurementRepository
    private let syncQueue = DispatchQueue(label: "LocalPhotoLibraryUpdateResource.syncQueue", attributes: .concurrent)
    private let queue = OperationQueue(underlyingQueue: DispatchQueue(label: "LocalPhotoLibraryUpdateResource", qos: .utility, attributes: .concurrent))

    @ThreadSafe private var fetchResult: PHFetchResult<PHAsset>?
    @ThreadSafe private var processedIdentifiers: Set<PhotoIdentifier>

    private var debounceableEnqueueUpdateCancellable: AnyCancellable?
    private let debounceableEnqueueUpdateSubject = PassthroughSubject<(Set<PhotoIdentifier>, PHFetchResult<PHAsset>), Never>()

    var updatePublisher: AnyPublisher<PhotoLibraryLoadUpdate, Never> {
        updateSubject
            .map { PhotoLibraryLoadUpdate.update($0) }
            .eraseToAnyPublisher()
    }

    init(mappingResource: PhotoLibraryMappingResource, optionsFactory: PHFetchOptionsFactory, queueRepository: PhotoLibraryIdentifiersQueueRepository, measurementRepository: DurationMeasurementRepository) {
        self.mappingResource = mappingResource
        self.optionsFactory = optionsFactory
        self.queueRepository = queueRepository
        self.measurementRepository = measurementRepository
        _fetchResult = ThreadSafe(wrappedValue: nil, queue: syncQueue)
        _processedIdentifiers = ThreadSafe(wrappedValue: [], queue: syncQueue)
    }

    func execute() {
        cancel()
        subscribeToEnqueueUpdate()
        updateFetchResult()
        PHPhotoLibrary.shared().register(self)
    }

    func cancel() {
        debounceableEnqueueUpdateCancellable?.cancel()
        queue.cancelAllOperations()
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func suspend() {
        queue.isSuspended = true
    }

    func resume() {
        queue.isSuspended = false
    }

    // MARK: - PHPhotoLibraryChangeObserver

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Log.info("\(Self.self): PHPhotoLibraryChangeObserver.photoLibraryDidChange 🌊", domain: .photosProcessing)
        guard let details = getChangeDetails(with: changeInstance) else {
            return
        }

        let fetchResultAfterChanges = details.fetchResultAfterChanges
        let assets = details.insertedObjects + details.changedObjects
        let allIdentifiers = Set(mappingResource.map(assets: assets))

        let identifiers = allIdentifiers.subtracting(processedIdentifiers)
        guard !identifiers.isEmpty else {
            Log.info("\(Self.self): skipping duplicate identifiers", domain: .photosProcessing)
            return
        }

        if isDebounceNeeded(for: identifiers) {
            // This api `photoLibraryDidChange` sometimes gets triggered twice for the same PHAsset. The asset undergoes some kind of processing so it's actually changed
            // the second time (modificationDate is different) so we're unable to mark it as duplicate by checking its metadata and also the content is different.
            // In these cases we can debounce the calls and only process the latest changes thus avoiding duplicate processing.
            Log.info("\(Self.self): will debounce \(identifiers.count) identifiers", domain: .photosProcessing)
            debounceableEnqueueUpdateSubject.send((identifiers, fetchResultAfterChanges))
        } else {
            // In cases when the update comes at a later point, we try to process the identifiers right away. (Example: app being woken from suspended time)
            Log.info("\(Self.self): will immediatelly process \(identifiers.count) identifiers", domain: .photosProcessing)
            enqueueUpdate(identifiers: identifiers, fetchResultAfterChanges: fetchResultAfterChanges)
        }
    }

    private func isDebounceNeeded(for identifiers: Set<PhotoIdentifier>) -> Bool {
        let currentDate = Date()
        let tresholdDate = currentDate.byAdding(.second, value: -10)
        return identifiers.contains(where: { identifier in
            (identifier.modifiedDate ?? currentDate) > tresholdDate
        })
    }

    private func enqueueUpdate(identifiers: Set<PhotoIdentifier>, fetchResultAfterChanges: PHFetchResult<PHAsset>) {
        let operation = CancellableBlockOperation { [weak self] in
            self?.handleUpdate(identifiers: identifiers, fetchResult: fetchResultAfterChanges)
        }
        queue.addOperation(operation)
    }

    private func handleUpdate(identifiers: Set<PhotoIdentifier>, fetchResult: PHFetchResult<PHAsset>) {
        Log.debug("\(Self.self): processing new identifiers", domain: .photosProcessing)
        measurementRepository.start()
        processedIdentifiers.formUnion(identifiers)
        self.fetchResult = fetchResult

        // We filter out identifiers that are already in the queue. If it's yet to be processed, then no need to add it again.
        // Even if there are modifications done to the asset, the processing will pick them up.
        let identifiersInQueue = queueRepository.get()
        let result = identifiers.filter { updatedIdentifier in
            !identifiersInQueue.contains(where: { $0.cloudIdentifier == updatedIdentifier.cloudIdentifier })
        }
        DispatchQueue.main.async { [weak self] in
            self?.updateSubject.send(Array(result))
            self?.measurementRepository.stop()
            Log.debug("\(Self.self): notified result", domain: .photosProcessing)
        }
    }

    private func getChangeDetails(with change: PHChange) -> PHFetchResultChangeDetails<PHAsset>? {
        guard let fetchResult = fetchResult else {
            return nil
        }
        return change.changeDetails(for: fetchResult)
    }

    private func updateFetchResult() {
        let options = optionsFactory.makeOptions()
        self.fetchResult = PHAsset.fetchAssets(with: options)
    }

    private func subscribeToEnqueueUpdate() {
        debounceableEnqueueUpdateCancellable = debounceableEnqueueUpdateSubject
            .debounce(for: .seconds(10), scheduler: RunLoop.main)
            .sink { [weak self] identifiers, fetchResultAfterChanges in
                self?.enqueueUpdate(identifiers: identifiers, fetchResultAfterChanges: fetchResultAfterChanges)
            }
    }
}
