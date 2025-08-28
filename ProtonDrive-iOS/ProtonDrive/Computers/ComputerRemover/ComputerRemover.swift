// Copyright (c) 2025 Proton AG
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
import CoreData

class ComputerRemover {
    private let client: DeviceDeleteDataSourceProtocol
    private let storage: StorageManager

    init(client: DeviceDeleteDataSourceProtocol, storage: StorageManager) {
        self.client = client
        self.storage = storage
    }

    public func delete(computer: DeviceIdentifier) async throws {
        let context = storage.backgroundContext
        try await client.deleteDevice(id: computer.id)

        try await context.perform {
            let device: Device = Device.fetchOrCreate(identifier: computer, in: context)
            let objects: [NSManagedObject] = [device, device.share, device.share.root].compactMap { $0 }
            objects.forEach(context.delete)
            try context.saveOrRollback()
        }
    }
}
