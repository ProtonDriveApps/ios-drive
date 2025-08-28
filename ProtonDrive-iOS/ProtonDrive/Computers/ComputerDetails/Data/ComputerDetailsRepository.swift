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
import Foundation

struct ComputerDetails {
    let decryptedName: String
    let creator: String
    let createdDate: Date
}

protocol ComputerDetailsRepositoryProtocol {
    func getComputerDetails() throws -> ComputerDetails
}

class ComputerDetailsRepository: ComputerDetailsRepositoryProtocol {
    let identifier: ComputerIdentifier
    let storageManager: StorageManager

    init(identifier: ComputerIdentifier, storageManager: StorageManager) {
        self.identifier = identifier
        self.storageManager = storageManager
    }

    func getComputerDetails() throws -> ComputerDetails {
        let context = storageManager.backgroundContext

        return try context.performAndWait {
            guard let device: Device = Device.fetch(identifier: identifier, in: context) else {
                throw ComputerRepositoryError.deviceNotFound
            }

            guard let root = device.share.root else {
                throw ComputerRepositoryError.rootNodeNotFound
            }

            guard let creator = root.signatureEmail else {
                throw ComputerRepositoryError.creatorNotFound
            }

            let info = ComputerDetails(
                decryptedName: root.decryptedName,
                creator: creator,
                createdDate: root.createdDate
            )
            return info
        }
    }

    enum ComputerRepositoryError: Error {
        case deviceNotFound
        case rootNodeNotFound
        case creatorNotFound
    }
}
