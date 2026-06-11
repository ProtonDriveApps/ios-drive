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
import PDCoreIOS

protocol VideoXAttrBackfillerProtocol {
    func backfillIfNeeded(videoURL: URL)
}

final class VideoXAttrBackfiller: VideoXAttrBackfillerProtocol {
    private let dependencies: Dependencies
    private let id: PhotoId

    init(dependencies: Dependencies, id: PhotoId) {
        self.dependencies = dependencies
        self.id = id
    }

    func backfillIfNeeded(videoURL: URL) {
        Task {
            await asyncBackfillIfNeeded(videoURL: videoURL)
        }
    }

    func asyncBackfillIfNeeded(videoURL: URL) async {
        do {
            guard
                let properties = try await dependencies.revisionReader.read(
                    photoIdentifier: id,
                    in: dependencies.managedContext
                ),
                let camera = properties.decryptedExtendedAttributes.camera,
                camera.device == nil
            else {
                Log.info("This video isn't required to perform xattr backfill", domain: .exifBackfill)
                return
            }
            Log.info("Sending xattr backfill", domain: .exifBackfill)
            let newXAttr = await getNewXAttr(remoteXAttr: properties.decryptedExtendedAttributes, videoURL: videoURL)
            await dependencies.backfiller.send(identifier: id, extendedAttributes: newXAttr)
        } catch {
            Log.error("Read revision failed", error: error, domain: .exifBackfill)
        }
    }
}

extension VideoXAttrBackfiller {
    private func getNewXAttr(remoteXAttr: ExtendedAttributes, videoURL: URL) async -> ExtendedAttributes {
        let camera = await dependencies.exifResource.getCameraInfo(at: videoURL, isVideo: true)
        let location = await dependencies.exifResource.getLocation(at: videoURL, isVideo: true)
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
            iOSPhotos: remoteXAttr.iOSPhotos
        )
        return xAttr
    }
}

extension VideoXAttrBackfiller {
    struct Dependencies {
        let analyzer: XAttrBackfillAnalyzer
        let backfiller: PhotoXAttrBatchBackfiller
        let exifResource: PhotoLibraryExifResource
        let revisionReader: PhotoRevisionReaderProtocol
        let managedContext: NSManagedObjectContext
    }
}
