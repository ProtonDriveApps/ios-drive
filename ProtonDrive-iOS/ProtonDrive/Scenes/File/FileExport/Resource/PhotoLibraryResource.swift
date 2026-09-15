// Copyright (c) 2026 Proton AG
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
import Photos
import PDPhotos

protocol PhotoLibraryResourceProtocol {
    func save(_ url: URL, mime: MimeType) async throws
}

final class PhotoLibraryResource: PhotoLibraryResourceProtocol {
    private lazy var authorizationResource = LocalPhotoLibraryAuthorizationResource()

    func save(_ url: URL, mime: MimeType) async throws {
        guard await hasPermission() else {
            throw FileExportError.noPhotoLibraryPermission
        }
        try await PHPhotoLibrary.shared().performChanges {
            if mime.isImage {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            } else if mime.isVideo {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        }
    }

    private func hasPermission() async -> Bool {
        switch await authorizationResource.authorize() {
        case .full:
            return true
        case .restricted, .undetermined:
            return false
        }
    }
}
