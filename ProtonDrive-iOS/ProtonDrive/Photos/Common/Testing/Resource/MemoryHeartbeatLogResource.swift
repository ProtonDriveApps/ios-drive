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

#if HAS_QA_FEATURES
protocol MemoryHeartbeatLogResource {}

final class PhotosMemoryHeartbeatLogResource: MemoryHeartbeatLogResource {
    private let resource: MemoryDiagnosticsResource
    private let storageManager: StorageManager
    private let managedObjectContext: NSManagedObjectContext
    private let queue = DispatchQueue(label: "MemoryHeartbeatLogResource", qos: .default)
    private var timer: Timer?

    init(resource: MemoryDiagnosticsResource, storageManager: StorageManager) {
        self.resource = resource
        self.storageManager = storageManager
        managedObjectContext = storageManager.newBackgroundContext()
        start()
    }

    private func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.queue.async {
                self?.handleUpdate()
            }
        }
    }

    private func handleUpdate() {
        guard let diagnostics = try? resource.getDiagnostics() else {
            return
        }

        let photosCount = storageManager.fetchMyPhotosCount(moc: managedObjectContext)
        Log.info("Memory dump: using \(diagnostics.usedMB) MB, total: \(diagnostics.totalMB) MB, photos in DB: \(photosCount).", domain: .diagnostics)
    }
}
#endif
