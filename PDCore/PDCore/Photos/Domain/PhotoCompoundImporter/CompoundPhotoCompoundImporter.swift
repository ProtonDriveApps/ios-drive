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
    private let moc: NSManagedObjectContext

    public init(importer: PhotoImporter, moc: NSManagedObjectContext) {
        self.importer = importer
        self.moc = moc
    }

    public func `import`(_ compound: PhotoAssetCompound) {
        do {
            let main = try importer.import(compound.primary)

            for secondaryAsset in compound.secondary {
                let secondary = try importer.import(secondaryAsset)
                main.children.insert(secondary)
            }

            try moc.saveOrRollback()

        } catch {
            ConsoleLogger.shared?.log(PhotoError(stage: .importPhoto, context: "CompoundPhotoCompoundImporter", error: error))
        }
    }

}
