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

import Combine
import PDCore

protocol DevicesRepositoryProtocol {
    var devices: AnyPublisher<[DeviceIdentifier], Never> { get }
}

final class DevicesRepository: DevicesRepositoryProtocol {
    private let storage: StorageManager
    private let deviceObserver: FetchedResultsControllerObserver<Device>

    init(storage: StorageManager) {
        let deviceFRC = storage.subscriptionToDevices(moc: storage.mainContext)
        self.storage = storage
        self.deviceObserver = FetchedResultsControllerObserver(controller: deviceFRC)
        deviceObserver.start()
    }

    var devices: AnyPublisher<[DeviceIdentifier], Never> {
        deviceObserver.getPublisher()
            .map { $0.compactMap(DeviceIdentifier.init) }
            .eraseToAnyPublisher()
    }

}

extension DeviceIdentifier {
    init?(device: Device) {
        guard let nodeID = device.share.root?.id else { return nil }
        self.init(id: device.id, nodeID: nodeID, shareID: device.share.id, volumeID: device.share.volumeID)
    }
}
