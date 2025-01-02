// Copyright (c) 2024 Proton AG
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
import Photos
import PDCore

protocol PhotosAssetsErrorMappingPolicy {
    func map(error: Error) -> PhotosFailureUserError
}

struct FoundationPhotosAssetsErrorMappingPolicy: PhotosAssetsErrorMappingPolicy {
    
    func map(error: Error) -> PhotosFailureUserError {
        let code = (error as NSError).code
        let isPhotoLibError = (error as NSError).domain == PHPhotosErrorDomain
        let deviceStorageFullCode = [NSFileWriteOutOfSpaceError, NSFileReadTooLargeError]
    
        if deviceStorageFullCode.contains(code) {
            return .deviceStorageFull
        } else if isPhotoLibError {
            if code == PHPhotosError.Code.notEnoughSpace.rawValue {
                return .deviceStorageFull
            } else if code == PHPhotosError.Code.accessRestricted.rawValue {
                return .missingPermission
            } else if #available(iOS 16, *), code == PHPhotosError.Code.networkError.rawValue {
                return .iCloudNotReachable
            }
            let invalidAssetCode = [
                PHPhotosError.Code.identifierNotFound.rawValue,
                PHPhotosError.Code.invalidResource.rawValue,
                PHPhotosError.Code.missingResource.rawValue,
                PHPhotosError.Code.multipleIdentifiersFound.rawValue
            ]
            if invalidAssetCode.contains(code) {
                return .accessFileFailed
            }
        } else if (error as? PhotoLibraryAssetsResourceError) == .invalidIdentifier {
            return .accessFileFailed
        } else if error is PhotoLibraryLivePhotoFilesResourceError {
            return .corruptedAsset
        }
        return .unknown
    }
}
