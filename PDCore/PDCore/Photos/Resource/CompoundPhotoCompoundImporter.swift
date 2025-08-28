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
import CoreData

public final class CompoundPhotoCompoundImporter: PhotoCompoundImporter {

    private let importer: PhotoImporter
    private let notificationCenter: NotificationCenter
    private let moc: NSManagedObjectContext
    private let rootRepository: PhotosRootFolderRepository
    private let existingPhotoRepository: ExistingPhotoCompoundRepository

    public init(
        importer: PhotoImporter, notificationCenter: NotificationCenter,
        moc: NSManagedObjectContext,
        rootRepository: PhotosRootFolderRepository,
        existingPhotoRepository: ExistingPhotoCompoundRepository
    ) {
        self.importer = importer
        self.moc = moc
        self.notificationCenter = notificationCenter
        self.rootRepository = rootRepository
        self.existingPhotoRepository = existingPhotoRepository
    }
    
    public func `import`(_ compounds: [PhotoAssetCompoundType]) async throws {
        var newCompounds = [PhotoAssetCompound]()
        var existingCompounds = [RawExistingCompound]()
        let shareID = try getEncryptingFolder().shareID
        let volumeID = try getEncryptingFolder().volumeID

        for compound in compounds {
            switch compound {
            case .new(let assetCompound):
                newCompounds.append(assetCompound)
                
            case .existing(linkID: let linkID, secondary: let assetCompound):
                existingCompounds.append(RawExistingCompound(shareID: shareID, mainPhotoID: linkID, assets: assetCompound, volumeID: volumeID))
            }
        }

        try await self.importCompounds(new: newCompounds, existing: existingCompounds)
    }
    
    private func importCompounds(new newCompounds: [PhotoAssetCompound], existing rawExistingCompounds: [RawExistingCompound]) async throws {
        let encryptingFolder = try getEncryptingFolder()
        let rootIdentifier = encryptingFolder.identifier

        try await moc.perform { [weak self] in
            guard let self else { return }
            guard let folder: Folder = Folder.fetch(identifier: rootIdentifier, in: moc) else {
                throw Folder.InvalidState(message: "Photos root not found with id: \(rootIdentifier)")
            }

            var importedCompounds: [ImportedPhoto] = []
            for newCompound in newCompounds {
                let importedCompound = try self.importNewCompound(newCompound, folder: folder, encryptingFolder: encryptingFolder)
                importedCompounds.append(importedCompound)
            }
            try self.moc.saveOrRollback()
            Log.info("imported \(newCompounds.count) new compound/s. \(importedCompounds)", domain: .photosProcessing)
            self.notificationCenter.post(name: .uploadPendingPhotos)
        }
        
        guard !rawExistingCompounds.isEmpty else { return }

        let existingCompounds = try await rawExistingCompounds.asyncMap(existingPhotoRepository.getExistingCompound)
        
        try await moc.perform { [weak self] in
            guard let self else { return }

            guard let folder: Folder = Folder.fetch(identifier: rootIdentifier, in: moc) else {
                throw Folder.InvalidState(message: "Photos root not found with id: \(rootIdentifier)")
            }

            for existingCompound in existingCompounds {
                try self.importExistingCompound(existingCompound, folder: folder, encryptingFolder: encryptingFolder)
            }
            
            try self.moc.saveOrRollback()
            Log.info("imported missing items of \(existingCompounds.count) partially uploaded compound/s.", domain: .photosProcessing)
            self.notificationCenter.post(name: .uploadPendingPhotos)
        }
    }

    private func importNewCompound(_ compound: PhotoAssetCompound, folder: Folder, encryptingFolder: EncryptingFolder) throws -> ImportedPhoto {
        let main = try importer.import(compound.primary, folder: folder, encryptingFolder: encryptingFolder)

        for secondaryAsset in compound.secondary {
            let secondary = try importer.import(secondaryAsset, folder: folder, encryptingFolder: encryptingFolder)
            secondary.parent = main
            main.addToChildren(secondary)
        }

        // Uses the new created upload id, or the id from the BE if already committed
        return ImportedPhoto(main: main.uploadID?.uuidString ?? main.id, secondary: main.children.map { $0.uploadID?.uuidString ?? $0.id })
    }
    
    private func importExistingCompound(_ compound: ExistingCompound, folder: Folder, encryptingFolder: EncryptingFolder) throws {
        let main = compound.mainPhoto.in(moc: moc)
        var childrenNames = main.children.map(\.decryptedName)
        for secondaryAsset in compound.assets {
            if childrenNames.contains(secondaryAsset.filename) {
                continue
            }
            childrenNames.append(secondaryAsset.filename)
            let secondary = try importer.import(secondaryAsset, folder: folder, encryptingFolder: encryptingFolder)
            secondary.parent = main
            main.addToChildren(secondary)
        }
    }
    
    private func getEncryptingFolder() throws -> EncryptingFolder {
        try rootRepository.getEncryptionInfo()
    }

    private struct ImportedPhoto: CustomStringConvertible {
        let main: String
        let secondary: [String]

        var description: String {
            let secondaryDescription = secondary.map { $0 }.joined(separator: ", ")
            return "Photo(main: \(main), secondary: [\(secondaryDescription)])"
        }
    }
}
