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

import Foundation
import PDCore
import ProtonDriveSDK
import PDSDKCore

public final class ThumbnailsUploadLocalCache: ThumbnailsUploadLocalCacheProtocol {
    public init() {}

    // Save thumbnail so that uploading file can show thumbnail rather than default icon
    public func save(thumbnails: [ThumbnailData], tempID: String, volumeID: String) async {
        let identifier = NodeIdentifier(tempID, "", volumeID)
        for thumbnail in thumbnails {
            await CoreDataThumbnail.saveClearDataToDisk(
                clearData: thumbnail.data,
                type: thumbnail.type.toCDType,
                identifier: identifier
            )
        }
    }

    public func moveTempThumbnails(from tempID: String, to nodeID: String, volumeID: String) {
        let tempIdentifier = NodeIdentifier(tempID, "", volumeID)
        let nodeIdentifier = NodeIdentifier(nodeID, "", volumeID)
        
        if let tempURL = PDFileManager.thumbnailURL(for: tempIdentifier, type: .default) {
            let url = PDFileManager.createThumbnailURL(for: nodeIdentifier, type: .default, storageType: .temporary)
            try? FileManager.default.moveItem(at: tempURL, to: url)
        }
        if let tempPreviewURL = PDFileManager.thumbnailURL(for: tempIdentifier, type: .photos) {
            let photoURL = PDFileManager.createThumbnailURL(for: nodeIdentifier, type: .photos, storageType: .temporary)
            try? FileManager.default.moveItem(at: tempPreviewURL, to: photoURL)
        }
    }
}
