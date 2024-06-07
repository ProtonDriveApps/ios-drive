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

extension Revision {
    var unsafeFullUploadableThumbnail: FullUploadableThumbnail? {
        thumbnails.first?.unsafeFullUploadableThumbnail
    }

    public var unsafeSortedUploadBlocks: [UploadBlock] {
        blocks.compactMap { $0 as? UploadBlock }.sorted(by: { $0.index < $1.index })
    }

    func uploadableUploadBlocks() -> [UploadBlock] {
        unsafeSortedUploadBlocks.filter({ !$0.isUploaded })
    }

    func uploadedBlocks() -> [UploadBlock] {
        unsafeSortedUploadBlocks.filter({ $0.isUploaded })
    }

    func uploadedThumbnails() -> [Thumbnail] {
        thumbnails.filter({ $0.isUploaded }).sorted(by: { $0.type.rawValue < $1.type.rawValue })
    }
}
