// Copyright (c) 2023 Proton AG
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

final class CachedPhotosRootEncryptingFolderDataSource: PhotosRootEncryptingFolderDataSource {
    private let repository: PhotosRootFolderRepository
    private let queue = DispatchQueue(label: "CachedPhotosRootEncryptingFolderDataSource", qos: .background, attributes: .concurrent)
    private var cachedFolder: EncryptingFolder?

    init(repository: PhotosRootFolderRepository) {
        self.repository = repository
    }

    func getEncryptingFolder() throws -> EncryptingFolder {
        try queue.sync {
            try getFolder()
        }
    }

    private func getFolder() throws -> EncryptingFolder {
        if let cachedFolder {
            return cachedFolder
        } else {
            return try getFolderFromDatabase()
        }
    }

    private func getFolderFromDatabase() throws -> EncryptingFolder {
        let folder = try repository.get()
        guard let managedObjectContext = folder.moc else {
            throw Folder.noMOC()
        }
        return try managedObjectContext.performAndWait {
            let encryptingFolder = try folder.encrypting()
            cachedFolder = encryptingFolder
            return encryptingFolder
        }
    }
}
