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

import Foundation
import PDCore
import CoreData

protocol CachingListedDeviceDataSourceProtocol {
    func cache(_ scannedDevices: [ScannedDevice]) async throws
}

extension StorageManager: CachingListedDeviceDataSourceProtocol {

    func cache(_ scannedDevices: [ScannedDevice]) async throws {
        let context = backgroundContext

        try await context.perform {
            for scannedDevice in scannedDevices {
                self.updateShare(scannedDevice.share, in: context)
                self.updateLinks([scannedDevice.link], in: context)
                self.updateDevice(scannedDevice.device, in: context)
            }
            try context.saveOrRollback()
        }
    }

    @discardableResult
    private func updateDevice(_ deviceMetadata: DeviceMetadata, in context: NSManagedObjectContext) -> CoreDataDevice {
        let volume = Volume.fetchOrCreate(id: deviceMetadata.volumeId, in: context)
        let share = Share.fetchOrCreate(id: deviceMetadata.shareId, in: context)
        let device = CoreDataDevice.fetchOrCreate(id: deviceMetadata.deviceId, volumeID: deviceMetadata.volumeId, in: context)

        share.volume = volume
        device.share = share
        device.volume = volume

        device.createTime = deviceMetadata.createTime
        device.modifyTime = deviceMetadata.modifyTime
        device.type = CoreDataDevice.´Type´.from(deviceMetadata.type)
        return device
    }
}

extension CoreDataDevice.´Type´ {
    static func from(_ metadataType: DeviceMetadata.DeviceType) -> CoreDataDevice.´Type´ {
        switch metadataType {
        case .windows: return .windows
        case .macOS: return .macOS
        case .linux: return .linux
        }
    }
}
