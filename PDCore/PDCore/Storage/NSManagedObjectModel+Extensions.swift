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

import CoreData

extension NSManagedObjectModel {
    static func makeModel() -> NSManagedObjectModel {
        // static linking
        if let resources = Bundle.main.resourceURL?.appendingPathComponent("PDCoreResources").appendingPathExtension("bundle"),
           let bundle = Bundle(url: resources)?.url(forResource: "Metadata", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: bundle)
        {
            return model
        }

        #if os(iOS)
        if let modelFilename = Constants.metadataModelUnderDevelopment,
           let model = getSpecificModel(modelFilename: modelFilename) {
            return model
        }
        #endif

        #if RESOURCES_ARE_IMPORTED_BY_SPM
        if let bundle = Bundle.module.url(forResource: "Metadata", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: bundle)
        {
            return model
        }
        #endif

        // dynamic linking
        if let bundle = Bundle(for: StorageManager.self).url(forResource: "Metadata", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: bundle)
        {
            return model
        }

        fatalError("Error loading Metadata from bundle")
    }

    private static func getSpecificModel(modelFilename: String) -> NSManagedObjectModel? {
        guard let bundleURL = Bundle.module.url(forResource: "Metadata", withExtension: "momd") else {
            return nil
        }

        let url = bundleURL.appending(path: modelFilename)
        return NSManagedObjectModel(contentsOf: url)
    }
}
