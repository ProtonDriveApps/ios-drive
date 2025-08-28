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
import PDClient
import Foundation

protocol ScannedDeviceDataSourceProtocol {
    func getScannedDevices() async throws -> [ScannedDevice]
}

extension Client: ScannedDeviceDataSourceProtocol {
    func getScannedDevices() async throws -> [ScannedDevice] {
        let credential = try credential()
        let endpoint = ListDevicesEndpoint(service: service, credential: credential)

        let devicesResponse = try await performRequest(on: endpoint)
        let devices = devicesResponse.devices

        guard !devices.isEmpty, let volumeId = devices.first?.device.volumeID else {
            return []
        }

        let linksIds = devices.map(\.share.linkID)
        let shareIds = devices.map(\.share.shareID)

        // Fetch link metadata
        let linksMetadata = try await getMetadata(forLinks: linksIds, inVolume: volumeId).links

        // Fetch share metadata concurrently
        let sharesMetadata = try await withThrowingTaskGroup(of: ShareMetadata.self) { group in
            for shareId in shareIds {
                group.addTask {
                    return try await self.bootstrapShare(id: shareId)
                }
            }
            return try await group.reduce(into: [ShareMetadata]()) { $0.append($1) }
        }

        // Map devices to ScannedDevice objects, ensuring all required data is available
        return devices.compactMap { deviceResponse -> ScannedDevice? in
            guard let linkMetadata = linksMetadata.first(where: { $0.linkID == deviceResponse.share.linkID }) else {
                return nil
            }

            guard let shareMetadata = sharesMetadata.first(where: { $0.shareID == deviceResponse.share.shareID }) else {
                return nil
            }

            return ScannedDevice(
                link: linkMetadata,
                share: shareMetadata,
                device: deviceResponse.mapToDeviceMetadata()
            )
        }
    }
}

extension ListDevicesEndpoint.Response.ShareDevice {
    func mapToDeviceMetadata() -> DeviceMetadata {
        return DeviceMetadata(
            deviceId: device.deviceID,
            shareId: share.shareID,
            volumeId: device.volumeID,
            createTime: device.creationTime,
            modifyTime: device.modifyTime ?? device.creationTime,
            type: DeviceMetadata.DeviceType.from(rawValue: device.type)
        )
    }
}

extension DeviceMetadata.DeviceType {
    static func from(rawValue: Int) -> DeviceMetadata.DeviceType {
        switch rawValue {
        case 1: return .windows
        case 2: return .macOS
        case 3: return .linux
        default: return .windows // Provide a default or handle unknown cases
        }
    }
}
