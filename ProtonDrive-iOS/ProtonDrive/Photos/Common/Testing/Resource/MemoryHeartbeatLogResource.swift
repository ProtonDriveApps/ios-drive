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
import PDCore
import CoreData
import Combine

protocol MemoryHeartbeatLogResource {}

final class PhotosMemoryHeartbeatLogResource: MemoryHeartbeatLogResource {
    private let lockedStateController: LockedStateControllerProtocol
    private let resource: MemoryDiagnosticsResource
    private let storageManager: StorageManager
    private let managedObjectContext: NSManagedObjectContext
    private let memoryPressureDispatchSource: DispatchSourceMemoryPressure
    private let queue = DispatchQueue(label: "MemoryHeartbeatLogResource", qos: .default)
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(lockedStateController: LockedStateControllerProtocol, resource: MemoryDiagnosticsResource, storageManager: StorageManager) {
        self.lockedStateController = lockedStateController
        self.resource = resource
        self.storageManager = storageManager
        managedObjectContext = storageManager.photosSecondaryBackgroundContext
        self.memoryPressureDispatchSource = DispatchSource.makeMemoryPressureSource(eventMask: .critical)

        #if HAS_QA_FEATURES
        subscribeToUpdates()
        #endif
        setUpMemoryPressureDispatchSource()
    }

    private func subscribeToUpdates() {
        lockedStateController.isLocked
            .sink { [weak self] isLocked in
                if isLocked {
                    self?.cancel()
                } else {
                    self?.start()
                }
            }
            .store(in: &cancellables)
    }

    private func setUpMemoryPressureDispatchSource() {
        let handler: DispatchSourceProtocol.DispatchSourceHandler = { [weak self] in
            guard let self, !self.memoryPressureDispatchSource.isCancelled else { return }
            let event = self.memoryPressureDispatchSource.data
            guard event == .critical else { return }

            handleCriticalMemory()
        }

        memoryPressureDispatchSource.setEventHandler(handler: handler)
        memoryPressureDispatchSource.setRegistrationHandler(handler: handler)
        memoryPressureDispatchSource.activate()
    }

    private func start() {
        cancel()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.queue.async {
                self?.handleUpdate()
            }
        }
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func handleUpdate() {
        guard let diagnostics = try? resource.getDiagnostics() else {
            return
        }

        let photosCount = storageManager.fetchActivePhotosCount(moc: managedObjectContext)
        Log.info("Memory dump: using \(diagnostics.usedMB) MB, total: \(diagnostics.totalMB) MB, active photos in DB: \(photosCount).", domain: .diagnostics)
    }

    private func handleCriticalMemory() {
        guard let diagnostics = try? resource.getDiagnostics() else {
            return
        }

        let sendToSentry = diagnostics.usedMB > 1_000 // only send to Sentry if the app's memory consumption is exceptionally high
        Log.info("Critical memory warning observed. Proton Drive app memory use: \(diagnostics.usedMB) MB", domain: .application, sendToSentryIfPossible: sendToSentry)
    }
}
