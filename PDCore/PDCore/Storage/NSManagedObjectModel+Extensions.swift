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

        #if RESOURCES_ARE_IMPORTED_BY_SPM && !canImport(XCTest)
        // Looking for the bundle via Bundle.module works fine for SPM packages linked to applications.
        if let bundle = Bundle.module.url(forResource: "Metadata", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: bundle)
        {
            return model
        }
        #elseif RESOURCES_ARE_IMPORTED_BY_SPM && canImport(XCTest)
        // But we need to do it manually for tests.
        if let libraryPath = ProcessInfo.processInfo.environment["DYLD_LIBRARY_PATH"]?.split(separator: ":").first,
           let resourceBundle = Bundle(path: libraryPath + "/PDCore_PDCore.bundle"),
           let modelURL = resourceBundle.url(forResource: "Metadata", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: modelURL)
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

        // Debug builds for real devices link XCTest in, causing problems when developing
        // on an iOS device. This doesn't happen for macOS.
        //
        // We work around this by trying the SPM/application code path even in case we
        // already tried looking for it in DYLD_LIBRARY_PATH.
        //
        // We shouldn't remove the compile-time checks because checking Bundle.module while
        // running macOS tests will crash as the resources aren't where it expects.
        if let url = Bundle.module.url(forResource: "Metadata", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: url) {
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
