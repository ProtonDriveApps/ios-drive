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

import Photos

enum PHAssetResourceError: Error {
    case invalidName
}

extension PHAssetResource {
    func isVideo() -> Bool {
        return UTType(uniformTypeIdentifier)?.isSubtype(of: .audiovisualContent) ?? false
    }

    func isImage() -> Bool {
        return UTType(uniformTypeIdentifier)?.isSubtype(of: .image) ?? false
    }

    func isOriginalPairedVideo() -> Bool {
        return type == .pairedVideo
    }

    func isAdjustedPairedVideo() -> Bool {
        return type == .fullSizePairedVideo
    }

    func isFullSizePhoto() -> Bool {
        return type == .fullSizePhoto
    }

    func isOriginalImage() -> Bool {
        return type == .photo
    }

    func isAdjustedImage() -> Bool {
        return type == .fullSizePhoto
    }

    func isAlternateImage() -> Bool {
        return type == .alternatePhoto
    }

    func isOriginalVideo() -> Bool {
        return isVideo() && type == .video
    }

    func isAdjustedVideo() -> Bool {
        return isVideo() && type == .fullSizeVideo
    }

    func isPartOfLivePhoto() -> Bool {
        isOriginalImage() || isOriginalPairedVideo() || isAdjustedImage() || isAdjustedPairedVideo()
    }

    func getNormalizedFilename() throws -> String {
        let name = originalFilename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty else {
            return String(name.suffix(255))
        }

        if let filenameExtension = UTType(uniformTypeIdentifier)?.preferredFilenameExtension {
            return Constants.photosPlaceholderAssetName + "." + filenameExtension
        } else {
            throw PHAssetResourceError.invalidName
        }
    }
}
