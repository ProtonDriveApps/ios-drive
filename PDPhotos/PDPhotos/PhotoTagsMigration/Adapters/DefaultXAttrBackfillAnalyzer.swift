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
import Foundation
import PDCore

protocol XAttrBackfillAnalyzer {
    func analyzeLocalAssetMetadata(
        assetMetadata: PhotoAssetMetadata,
        photo: Photo,
        context: NSManagedObjectContext
    ) async -> XAttrBackfillContext

    func analyzeFile(
        inspector: ImageInspector,
        photo: Photo,
        context: NSManagedObjectContext
    ) async -> XAttrBackfillContext
}

/// Suitable for photos
final class DefaultXAttrBackfillAnalyzer: XAttrBackfillAnalyzer {
    private let exifResource: PhotoLibraryExifResource
    private let dateFormatter: ISO8601DateFormatter

    init(
        exifResource: PhotoLibraryExifResource,
        dateFormatter: ISO8601DateFormatter = .init()
    ) {
        self.exifResource = exifResource
        self.dateFormatter = dateFormatter
    }

    func analyzeLocalAssetMetadata(
        assetMetadata: PhotoAssetMetadata,
        photo: Photo,
        context: NSManagedObjectContext
    ) async -> XAttrBackfillContext {
        guard
            // Backfill operation requires existing extended attributes
            let remoteXAttr = await getRemoteXAttr(photo: photo, context: context)
        else { return XAttrBackfillContext(extendedAttributes: nil, control: .abort) }

        guard remoteXAttr.camera?.device == nil else {
            // Photo has `device` already do migration
            return XAttrBackfillContext(extendedAttributes: nil, control: .upToDate)
        }

        let temp = TemporalMetadata(metadata: assetMetadata)
        let xAttr = ExtendedAttributes(
            common: remoteXAttr.common,
            location: temp.location,
            camera: ExtendedAttributes.Camera(
                captureTime: remoteXAttr.camera?.captureTime,
                device: temp.camera?.device,
                orientation: temp.camera?.orientation,
                subjectCoordinates: temp.camera?.subjectCoordinates
            ),
            media: remoteXAttr.media,
            iOSPhotos: remoteXAttr.iOSPhotos
        )
        return XAttrBackfillContext(extendedAttributes: xAttr, control: .finished)
    }

    func analyzeFile(
        inspector: ImageInspector,
        photo: Photo,
        context: NSManagedObjectContext
    ) async -> XAttrBackfillContext {
        guard let properties = inspector.properties else {
            return XAttrBackfillContext(extendedAttributes: nil, control: .abort)
        }
        guard
            let remoteXAttr = await getRemoteXAttr(photo: photo, context: context),
            let iOSPhotos = remoteXAttr.iOSPhotos
        else { return XAttrBackfillContext(extendedAttributes: nil, control: .abort) }
        guard remoteXAttr.camera?.device == nil else {
            // Photo has `device` already do migration
            return XAttrBackfillContext(extendedAttributes: nil, control: .upToDate)
        }
        let location = exifResource.getLocation(from: properties as NSDictionary)
        let camera = exifResource.getCameraInfo(from: properties as NSDictionary)

        let xAttr = ExtendedAttributes(
            common: remoteXAttr.common,
            location: ExtendedAttributes.Location(location: location),
            camera: ExtendedAttributes.Camera(
                captureTime: remoteXAttr.camera?.captureTime,
                device: camera.device,
                orientation: camera.orientation,
                subjectCoordinates: ExtendedAttributes.SubjectCoordinates(subjectCoordinates: camera.subjectCoordinates)
            ),
            media: remoteXAttr.media,
            iOSPhotos: iOSPhotos
        )
        return XAttrBackfillContext(extendedAttributes: xAttr, control: .finished)
    }
}

extension DefaultXAttrBackfillAnalyzer {
    private func getRemoteXAttr(
        photo: Photo,
        context: NSManagedObjectContext
    ) async -> ExtendedAttributes? {
        do {
            return try await context.perform {
                try photo.photoRevision.decryptedExtendedAttributes()
            }
        } catch {
            Log.error("Failed to decrypted remote xAttr", error: error, domain: .exifBackfill)
            return nil
        }
    }
}
