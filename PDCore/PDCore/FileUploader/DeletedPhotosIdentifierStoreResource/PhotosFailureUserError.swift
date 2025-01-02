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
import PDLocalization

/// Error with user friendly failure reason
public enum PhotosFailureUserError: Error {
    case accessFileFailed
    case connectionError
    case corruptedAsset
    case deviceStorageFull
    case driveStorageFull
    case encryptionFailed
    case iCloudNotReachable
    case loadResourceFailed
    case missingPermission
    case nameValidationError
    case unknown
    
    public var localizedDescription: String {
        switch self {
        case .accessFileFailed, .corruptedAsset:
            return Localization.retry_error_explainer_invalid_asset
        case .connectionError:
            return Localization.retry_error_explainer_connection_error
        case .deviceStorageFull:
            return Localization.retry_error_explainer_device_storage_full
        case .driveStorageFull:
            return Localization.retry_error_explainer_quote_exceeded
        case .encryptionFailed:
            return Localization.retry_error_explainer_encryption_error
        case .iCloudNotReachable:
            return Localization.retry_error_explainer_cannot_connect_icloud
        case .loadResourceFailed:
            return Localization.retry_error_explainer_failed_to_load_resource
        case .missingPermission:
            return Localization.retry_error_explainer_missing_permissions
        case .nameValidationError:
            return Localization.retry_error_explainer_name_validation
        case .unknown:
            return ""
        }
    }
}

extension PhotosFailureUserError: LocalizedError {
    public var errorDescription: String? {
        localizedDescription
    }
}
