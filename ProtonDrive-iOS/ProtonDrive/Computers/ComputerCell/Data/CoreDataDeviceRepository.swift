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
import Combine
import CoreData
import PDCore

final class CoreDataDeviceRepository: DeviceRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func observeComputer(with identifier: ComputerIdentifier) -> AnyPublisher<Computer, Error> {
        return Future<(CoreDataDevice, CoreDataNode), Error> { promise in
            self.context.perform {
                guard let device = CoreDataDevice.fetch(identifier: identifier, in: self.context) else {
                    promise(.failure(CoreDataDevice.InvalidState(message: "No device found for that identifier")))
                    return
                }

                guard let root = device.share.root else {
                    promise(.failure(CoreDataDevice.InvalidState(message: "No root node found for device")))
                    return
                }

                promise(.success((device, root)))
            }
        }
        .flatMap { (device, root) in
            // Create an initial publisher with the current device value
            let initialPublisher = Just(device)
                .setFailureType(to: Error.self)

            let devicePublisher = device.objectWillChange
                .setFailureType(to: Error.self)
                .map { _ in
                    device
                }

            let nodePublisher = root.objectWillChange
                .setFailureType(to: Error.self)
                .map { _ in
                    device
                } // We return `device` so that both publishers emit the same type

            return initialPublisher.merge(with: devicePublisher.combineLatest(nodePublisher).map { device, _ in device })
        }
        .filter { $0.isDeleted == false }
        .tryMap { device in
            try self.transform(device, identifier)
        }
        .eraseToAnyPublisher()
    }

    private func transform(_ device: CoreDataDevice, _ identifier: ComputerIdentifier) throws -> Computer {
        let decryptedName = try device.decryptedName()
        return Computer(
            identifier: identifier,
            type: mapOSType(device.type),
            decryptedName: decryptedName
        )
    }

    private func mapOSType(_ type: CoreDataDevice.´Type´) -> Computer.OS {
        switch type {
        case .windows:
            return .windows
        case .macOS:
            return .macOS
        case .linux:
            return .linux
        default:
            return .other
        }
    }
}
