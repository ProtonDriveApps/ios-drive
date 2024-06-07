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
import Photos
import PDCore

enum PhotoAssetErrorPolicyResult {
    case generic(Error)
    case temporaryError
    case missingAsset
    case updatedIdentifier(PhotoIdentifier)
}

protocol PhotoAssetErrorPolicy {
    func map(error: Error) -> PhotoAssetErrorPolicyResult
}

final class FoundationPhotoAssetErrorPolicy: PhotoAssetErrorPolicy {
    func map(error: Error) -> PhotoAssetErrorPolicyResult {
        if isTemporaryError(error: error) {
            return .temporaryError
        } else if isMissingAsset(error: error) {
            return .missingAsset
        } else if let updatedIdentifier = getUpdatedIdentifier(error: error) {
            return .updatedIdentifier(updatedIdentifier)
        } else {
            return .generic(error)
        }
    }

    private func isTemporaryError(error: Error) -> Bool {
        return isStorageError(error: error) || isPhotosTemporaryError(error: error)
    }

    private func isMissingAsset(error: Error) -> Bool {
        return isInvalidIdentifier(error: error) || isInvalidAsset(error: error)
    }

    private func getUpdatedIdentifier(error: Error) -> PhotoIdentifier? {
        if case let .obsoleteIdentifier(updatedIdentifier) = (error as? PhotoLibraryAssetsResourceError) {
            return updatedIdentifier
        } else {
            return nil
        }
    }

    private func isStorageError(error: Error) -> Bool {
        let code = (error as NSError).code
        return [
            NSFileWriteOutOfSpaceError,
            NSFileReadTooLargeError,
        ].contains(code)
    }

    private func isPhotosTemporaryError(error: Error) -> Bool {
        guard (error as NSError).domain == PHPhotosErrorDomain else {
            return false
        }

        var codes = [
            PHPhotosError.Code.notEnoughSpace,
            .accessRestricted,
        ]
        if #available(iOS 16, *) {
            codes.append(.networkError)
        }
        let code = (error as NSError).code
        return codes.map(\.rawValue).contains(code)
    }

    private func isInvalidIdentifier(error: Error) -> Bool {
        return (error as? PhotoLibraryAssetsResourceError) == .invalidIdentifier
    }

    private func isInvalidAsset(error: Error) -> Bool {
        guard (error as NSError).domain == PHPhotosErrorDomain else {
            return false
        }

        let code = (error as NSError).code
        return [
            PHPhotosError.Code.identifierNotFound,
            PHPhotosError.Code.invalidResource,
            PHPhotosError.Code.missingResource,
            PHPhotosError.Code.multipleIdentifiersFound
        ].map(\.rawValue).contains(code)
    }
}
