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

public protocol PhotosSkippableCache {
    typealias Identifier = PhotoAssetMetadata.iOSPhotos
    func markAsSkippable(_ identifier: Identifier, skippableFiles: Int)
    /// [Identifier: skippableFiles]
    func batchMarkAsSkippable(_ data: [Identifier: Int])
    func recordFiles(identifier: Identifier, filesToUpload: Int)
    func isSkippable(_ identifier: Identifier) -> Bool
    func checkSkippableStatus(_ identifier: Identifier) -> SkippableStatus
}

public final class ConcretePhotosSkippableCache: PhotosSkippableCache {

    public init(storage: PhotosSkippableStorage) {
        self.storage = storage
    }
    
    private var storage: PhotosSkippableStorage

    private func prepare(_ identifier: Identifier) -> Identifier {
        identifier.rounded()
    }

    public func recordFiles(identifier: Identifier, filesToUpload: Int) {
        let identifier = prepare(identifier)
        storage[identifier] = filesToUpload
        Log.debug("Skippable status of \(identifier) reset to \(filesToUpload)", domain: .photosProcessing)
    }
    
    public func markAsSkippable(_ identifier: Identifier, skippableFiles: Int) {
        let identifier = prepare(identifier)
        guard storage[identifier] != nil else {
            Log.error("Tried to modify skippable status of \(identifier.rounded()) which can not be found in skippable table.", domain: .photosProcessing)
            storage[identifier] = skippableFiles
            return
        }
        storage[identifier] = max(0, storage[identifier]! - skippableFiles)
        Log.debug("Skippable status of \(identifier) updated to " + String(describing: storage[identifier]), domain: .photosProcessing)
    }
    
    public func isSkippable(_ identifier: Identifier) -> Bool {
        let identifier = prepare(identifier)
        let canSkip = storage[identifier] == 0
        #if DEBUG // Creates too much noise
        Log.debug("Check skippable status of \(identifier): " + String(describing: storage[identifier]) + ". Should be 0 for skipping.", domain: .photosProcessing)
        #endif
        return canSkip
    }
    
    public func checkSkippableStatus(_ identifier: Identifier) -> SkippableStatus {
        let identifier = prepare(identifier)
        return storage.checkSkippableStatus(identifier: identifier)
    }
    
    public func batchMarkAsSkippable(_ data: [Identifier: Int]) {
        var result: [Identifier: Int] = [:]
        for (id, value) in data {
            let id = prepare(id)
            result[id] = value
        }
        storage.batchMarkAsSkippable(data: result)
    }
}

extension PhotosSkippableCache {
    public func recordFiles(identifier: PhotoIdentifier, filesToUpload: Int) {
        let iOSPhotos = PhotoAssetMetadata.iOSPhotos(identifier: identifier.cloudIdentifier, modificationTime: identifier.modifiedDate)
        recordFiles(identifier: iOSPhotos, filesToUpload: filesToUpload)
    }
    
    public func markAsSkippable(_ identifier: PhotoIdentifier, skippableFiles: Int) {
        let iOSPhotos = PhotoAssetMetadata.iOSPhotos(identifier: identifier.cloudIdentifier, modificationTime: identifier.modifiedDate)
        markAsSkippable(iOSPhotos, skippableFiles: skippableFiles)
    }
    
    public func isSkippable(_ identifier: PhotoIdentifier) -> Bool {
        let iOSPhotos = PhotoAssetMetadata.iOSPhotos(identifier: identifier.cloudIdentifier, modificationTime: identifier.modifiedDate)
        return isSkippable(iOSPhotos)
    }
    
    public func checkSkippableStatus(_ identifier: PhotoIdentifier) -> SkippableStatus {
        let iOSPhotos = PhotoAssetMetadata.iOSPhotos(identifier: identifier.cloudIdentifier, modificationTime: identifier.modifiedDate)
        return checkSkippableStatus(iOSPhotos)
    }
    
    public func batchMarkAsSkippable(_ data: [PhotoIdentifier: Int]) {
        var result: [Identifier: Int] = [:]
        for (identifier, value) in data {
            let iOSPhotos = PhotoAssetMetadata.iOSPhotos(
                identifier: identifier.cloudIdentifier,
                modificationTime: identifier.modifiedDate
            )
            result[iOSPhotos] = value
        }
        batchMarkAsSkippable(result)
    }
}

public final class BlankPhotosSkippableCache: PhotosSkippableCache {
    public func markAsSkippable(_ identifier: Identifier, skippableFiles: Int) { }
    public func recordFiles(identifier: Identifier, filesToUpload: Int) { }
    public func discard() { }
    public init() { }
    
    public func isSkippable(_ identifier: Identifier) -> Bool {
        false
    }
    public func checkSkippableStatus(_ identifier: Identifier) -> SkippableStatus {
        .newAsset
    }
    public func batchMarkAsSkippable(_ data: [Identifier: Int]) {}
}

extension PhotoAssetMetadata.iOSPhotos {
    func rounded() -> Self {
        if let timestamp = modificationTime?.timeIntervalSinceReferenceDate {
            let rounded = TimeInterval(Int(timestamp))
            return Self(identifier: identifier, modificationTime: Date(timeIntervalSinceReferenceDate: rounded))
        } else {
            return self
        }
    }
}
