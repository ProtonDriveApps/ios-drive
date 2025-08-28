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
    private let scheduled: NSMapTable<NSString, ThumbnailIdentifiableOperation> = NSMapTable(keyOptions: .copyIn, valueOptions: .weakMemory)
    private let regulatingQueue = DispatchQueue(label: "thumbnail.loader.queue", qos: .userInitiated, attributes: .concurrent)
    private let operationsFactory: ThumbnailOperationsFactory
    private let failedIdSubject = PassthroughSubject<Identifier, Never>()
    private let succeededIdSubject = PassthroughSubject<Identifier, Never>()

    let schedulingQueue = OperationQueue()

    var succeededId: AnyPublisher<Identifier, Never> {
        succeededIdSubject.eraseToAnyPublisher()
    }

    var failedId: AnyPublisher<Identifier, Never> {
        failedIdSubject.eraseToAnyPublisher()
    }

    init(operationsFactory: ThumbnailOperationsFactory) {
        self.operationsFactory = operationsFactory
        schedulingQueue.maxConcurrentOperationCount = 10
    }
}

extension AsyncThumbnailLoader {
    func loadThumbnail(with id: Identifier) {
        guard isIdAllowed(id) else {
            Log.info("Load thumbnail not allowed: \(id)", domain: .thumbnails)
            failedIdSubject.send(id)
            return
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
    private func canScheduleOperation(_ id: Identifier) -> Bool {
        regulatingQueue.sync {
            isNotScheduled(id)
        }
    }

    private func isIdAllowed(_ id: Identifier) -> Bool {
        regulatingQueue.sync {
            isAllowed(id)
        }
    }

    private func isAllowed(_ id: Identifier) -> Bool {
        return !denied.contains(id.any())
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
}

protocol ThumbnailLoaderDelegate: AnyObject {
    func finishOperationWithSuccess(_ id: NodeIdentifier)
    func finishOperationWithFailure(_ id: NodeIdentifier, error: Error)
}

private extension VolumeIdentifiable {
    var thumbnailLoaderIdentifier: NSString {
        NSString(string: id + volumeID)
    }
}
