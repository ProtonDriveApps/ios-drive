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
import PDClient

extension Thumbnail {
    var uploadable: UploadableThumbnail? {
        guard let thumbnailData = encrypted,
              let sha256 = sha256 else { return nil }

        return UploadableThumbnail(
            revisionId: revision.identifier,
            type: Int(type.rawValue),
            encrypted: thumbnailData,
            sha256: sha256
        )
    }

    var uploading: FullUploadableThumbnail? {
        let uploadThumbnail: FullUploadableThumbnail? = managedObjectContext!.performAndWait {
            guard let uploadableThumbnail = uploadable,
                  let urlString = uploadURL,
                  let url = URL(string: urlString) else { return nil }
            return FullUploadableThumbnail(uploadURL: url, uploadable: uploadableThumbnail)
        }
        return uploadThumbnail
    }

    var unsafeFullUploadableThumbnail: FullUploadableThumbnail? {
        guard let uploadableThumbnail = uploadable,
              let remoteURLString = uploadURL,
              let remoteURL = URL(string: remoteURLString) else {
                  return nil
              }
        return FullUploadableThumbnail(uploadURL: remoteURL, uploadable: uploadableThumbnail)
    }
}
