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

final class ProtonDocumentIdentifierRepository: ProtonDocumentIdentifierRepositoryProtocol {
    private let sessionVault: SessionVault
    private let storageManager: StorageManager
    private let managedObjectContext: NSManagedObjectContext

    init(sessionVault: SessionVault, storageManager: StorageManager, managedObjectContext: NSManagedObjectContext) {
        self.sessionVault = sessionVault
        self.storageManager = storageManager
        self.managedObjectContext = managedObjectContext
    }

    func getIdentifier(from identifier: NodeIdentifier) throws -> ProtonDocumentIdentifier {
        guard let file = storageManager.fetchNode(id: identifier, moc: managedObjectContext) as? File else {
            throw ProtonDocumentOpeningError.missingFile
        }
        return try managedObjectContext.performAndWait {
            try getIdentifier(from: file)
        }
    }

    private func getIdentifier(from file: File) throws -> ProtonDocumentIdentifier {
        guard file.isProtonDocument else {
            throw ProtonDocumentOpeningError.invalidFileType
        }
        guard let share = file.parentsChain().first?.primaryDirectShare else {
            throw ProtonDocumentOpeningError.missingDirectShare
        }
        guard let email = getEmailFromShare(share) ?? getCurrentEmail() else {
            throw ProtonDocumentOpeningError.missingAddress
        }
        guard let volumeId = share.volume?.id else {
            throw ProtonDocumentOpeningError.missingVolume
        }
        return ProtonDocumentIdentifier(volumeId: volumeId, linkId: file.id, email: email)
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
