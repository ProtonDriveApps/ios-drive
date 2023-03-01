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

protocol ThumbnailModel {
    typealias Identifier = RevisionIdentifier
    typealias FileIdentifier = NodeIdentifier

    var id: Identifier { get }
    var fileId: FileIdentifier { get }
}

extension ThumbnailModel {
    var fileId: FileIdentifier {
        .init(id.file, id.share)
    }
}

/// `FullThumbnail` represents a thumbnail object that has available the locally its encrypted data. Can be found on fully downloaded thumbnails or thumbnails that were created and uploaded
struct FullThumbnail: ThumbnailModel, Equatable {
    let id: Identifier
    let encrypted: Data
}

/// `InProgressThumbnail` represents a thumbnail object that has available the URL used to download the encrypted thumbnail. Can be found when we enter a new folder that has requested some folder's children.
struct InProgressThumbnail: ThumbnailModel, Equatable {
    let id: Identifier
    let url: URL
}

/// `IncompleteThumbnail` represents a the existence of a thumbnail in a revision, but for which we don't have neither the URL nor the encrypted data. Can be found for example when some trashed file is restored and we don't have its fullmetadata.
struct IncompleteThumbnail: ThumbnailModel, Equatable {
    let id: Identifier
}

/// `UploadableThumbnail` a thumbnail ready to start the uploading process, but for which we don't yet have the URL to be uploaded.
struct UploadableThumbnail: ThumbnailModel, Equatable {
    let id: Identifier
    let encrypted: Data
    let sha256: Data
}

/// `FullUploadableThumbnail` represents a thumbnail ready to be uploaded, the uploadURL property is the URL where the encrypted data should be uploaded.
struct FullUploadableThumbnail: ThumbnailModel {
    let uploadURL: URL
    let uploadable: UploadableThumbnail

    var id: Identifier {
        uploadable.id
    }
}
