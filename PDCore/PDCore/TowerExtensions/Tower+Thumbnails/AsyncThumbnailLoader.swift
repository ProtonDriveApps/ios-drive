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
import Combine

final class AsyncThumbnailLoader: CancellableThumbnailLoader {
    private var denied = Set<AnyVolumeIdentifier>() // cannot be `Identifier`, needs to use concrete struct
    private var emptyThumbnails = Set<AnyVolumeIdentifier>() // Identifiers that don't have any thumbnails currently, to prevent further fetching
    private let scheduled: NSMapTable<NSString, ThumbnailIdentifiableOperation> = NSMapTable(keyOptions: .copyIn, valueOptions: .weakMemory)
    private let regulatingQueue = DispatchQueue(label: "thumbnail.loader.queue", qos: .userInitiated, attributes: .concurrent)
    private let operationsFactory: ThumbnailOperationsFactory
    private let failedIdSubject = PassthroughSubject<Identifier, Never>()
    private let succeededIdSubject = PassthroughSubject<Identifier, Never>()
    private let useSDK: () -> Bool

    let schedulingQueue = OperationQueue()

    var succeededId: AnyPublisher<Identifier, Never> {
        succeededIdSubject.eraseToAnyPublisher()
    }

    var failedId: AnyPublisher<Identifier, Never> {
        failedIdSubject.eraseToAnyPublisher()
    }

    init(operationsFactory: ThumbnailOperationsFactory, useSDK: @escaping () -> Bool) {
        self.operationsFactory = operationsFactory
        self.useSDK = useSDK
        schedulingQueue.maxConcurrentOperationCount = 10
    }
}

extension AsyncThumbnailLoader {
    func loadThumbnail(with id: Identifier) {
        let loadPossibility = getLoadPossibility(id)
        switch loadPossibility {
        case .deniedDueToPreviousError:
            Log.debug("Load thumbnail not allowed: \(id)", domain: .thumbnails)
            failedIdSubject.send(id)
            return
        case .deniedDueToEmptyThumbnails:
            Log.debug("Load thumbnail not needed, file has no thumbnail: \(id)", domain: .thumbnails)
            return
        case .possible:
            // Continues below
            break
        }

        guard canScheduleOperation(id) else {
            return
        }

        do {
            let operation = try operationsFactory.makeThumbnailModel(forFileWithID: id)
            operation.delegate = self
            scheduleOperation(operation, key: id)
        } catch ThumbnailLoaderError.nonRecoverable {
            Log.warning("Non recoverable load error: \(id)", domain: .thumbnails)
            handlingNonRecoverableError(id: id)
            removeScheduledOperation(with: id)
            failedIdSubject.send(id)
        } catch {
            Log.warning("Load error: \(id), \(error.localizedDescription)", domain: .thumbnails)
            removeScheduledOperation(with: id)
            failedIdSubject.send(id)
        }
    }

    func loadThumbnailAsync(with id: Identifier) async {
        let loadPossibility = getLoadPossibility(id)
        switch loadPossibility {
        case .deniedDueToPreviousError:
            Log.debug("Load thumbnail not allowed: \(id)", domain: .thumbnails)
            failedIdSubject.send(id)
            return
        case .deniedDueToEmptyThumbnails:
            Log.debug("Load thumbnail not needed, file has no thumbnail: \(id)", domain: .thumbnails)
            return
        case .possible:
            // Continues below
            break
        }

        guard canScheduleOperation(id) else {
            return
        }

        do {
            let operation = try await operationsFactory.makeThumbnailModelAsync(forFileWithID: id)
            operation.delegate = self
            scheduleOperation(operation, key: id)
        } catch ThumbnailLoaderError.nonRecoverable {
            Log.warning("Non recoverable load error: \(id)", domain: .thumbnails)
            handlingNonRecoverableError(id: id)
            removeScheduledOperation(with: id)
            failedIdSubject.send(id)
        } catch {
            Log.warning("Load error: \(id), \(error.localizedDescription)", domain: .thumbnails)
            removeScheduledOperation(with: id)
            failedIdSubject.send(id)
        }
    }

    func cancelThumbnailLoading(_ id: Identifier) {
        scheduled.object(forKey: id.thumbnailLoaderIdentifier)?.cancel()
    }

    func cancelAll() {
        schedulingQueue.cancelAllOperations()
        scheduled.removeAllObjects()
        denied.removeAll()
    }
}

extension AsyncThumbnailLoader {
    enum LoadingPosibility {
        case deniedDueToPreviousError
        case deniedDueToEmptyThumbnails
        case possible
    }

    private func canScheduleOperation(_ id: Identifier) -> Bool {
        // ThumbnailsBatchDownloader takes over the responsibility
        if useSDK() { return true }
        return regulatingQueue.sync {
            isNotScheduled(id)
        }
    }

    private func getLoadPossibility(_ id: Identifier) -> LoadingPosibility {
        return regulatingQueue.sync {
            let id = id.any()
            if denied.contains(id) {
                return .deniedDueToPreviousError
            } else if emptyThumbnails.contains(id) {
                return .deniedDueToEmptyThumbnails
            } else {
                return .possible
            }
        }
    }

    private func isNotScheduled(_ id: Identifier) -> Bool {
        return scheduled.object(forKey: id.thumbnailLoaderIdentifier) == nil
    }

    private func scheduleOperation(_ operation: ThumbnailIdentifiableOperation, key: Identifier) {
        regulatingQueue.async(flags: .barrier) {
            self.scheduled.setObject(operation, forKey: key.thumbnailLoaderIdentifier)
            self.schedulingQueue.addOperation(operation)
        }
    }

    private func handlingNonRecoverableError(id: Identifier) {
        regulatingQueue.async(flags: .barrier) {
            self.denied.insert(id.any())
        }
    }

    private func removeScheduledOperation(with id: Identifier) {
        regulatingQueue.async(flags: .barrier) {
            self.scheduled.setObject(nil, forKey: id.thumbnailLoaderIdentifier)
        }
    }

    private func insertNoThumbnailsNode(with id: Identifier) {
        regulatingQueue.async(flags: .barrier) {
            self.emptyThumbnails.insert(id.any())
        }
    }
}

extension AsyncThumbnailLoader: ThumbnailLoaderDelegate {
    func finishOperationWithSuccess(_ id: NodeIdentifier) {
        removeScheduledOperation(with: id)
        succeededIdSubject.send(id)
    }

    func finishOperationWithFailure(_ id: NodeIdentifier, error: Error) {
        Log.info("finishOperationWithFailure, \(error.localizedDescription)", domain: .thumbnails)
        switch error {
        case ThumbnailLoaderError.nonRecoverable:
            handlingNonRecoverableError(id: id)
            removeScheduledOperation(with: id)

        default:
            removeScheduledOperation(with: id)
        }
        failedIdSubject.send(id)
    }

    func finishOperationWithEmpty(_ id: NodeIdentifier) {
        insertNoThumbnailsNode(with: id)
        removeScheduledOperation(with: id)
        // Doesn't publish an update, since no thumbnail was downloaded
    }
}

protocol ThumbnailLoaderDelegate: AnyObject {
    func finishOperationWithSuccess(_ id: NodeIdentifier)
    func finishOperationWithFailure(_ id: NodeIdentifier, error: Error)
    func finishOperationWithEmpty(_ id: NodeIdentifier)
}

private extension VolumeIdentifiable {
    var thumbnailLoaderIdentifier: NSString {
        NSString(string: id + volumeID)
    }
}
