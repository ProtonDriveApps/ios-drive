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

import CoreData

final class ProtonFileIdentifierRepository: ProtonFileIdentifierRepositoryProtocol {
    private let sessionVault: SessionVault
    private let storageManager: StorageManager
    private let managedObjectContext: NSManagedObjectContext

    init(sessionVault: SessionVault, storageManager: StorageManager, managedObjectContext: NSManagedObjectContext) {
        self.sessionVault = sessionVault
        self.storageManager = storageManager
        self.managedObjectContext = managedObjectContext
    }

    func getIdentifier(from identifier: NodeIdentifier) throws -> ProtonFileIdentifier {
        guard let file = storageManager.fetchNode(id: identifier, moc: managedObjectContext) as? File else {
            throw ProtonFileOpeningError.missingFile
        }
        return try managedObjectContext.performAndWait {
            try getIdentifier(from: file)
        }
    }

    private func getIdentifier(from file: File) throws -> ProtonFileIdentifier {
        guard let type = file.protonFileType else {
            throw ProtonFileOpeningError.invalidFileType
        }
        guard let share = try? file.getContextShare() else {
            throw ProtonFileOpeningError.missingDirectShare
        }
        guard let email = getEmailFromShare(share) ?? getCurrentEmail() else {
            throw ProtonFileOpeningError.missingAddress
        }
        guard let volumeId = !file.volumeID.isEmpty ? file.volumeID : share.volume?.id else {
            throw ProtonFileOpeningError.missingVolume
        }

        return ProtonFileIdentifier(volumeId: volumeId, shareId: share.id, linkId: file.id, email: email, type: type)
    }

    private func getEmailFromShare(_ share: Share) -> String? {
        guard let addressID = share.addressID else {
            return nil
        }
        return sessionVault.getEmail(addressId: addressID)
    }

    private func getCurrentEmail() -> String? {
        sessionVault.currentAddress()?.email
    }
}
