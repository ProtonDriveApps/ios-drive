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
import PDLocalization

public enum SDKUploadErrors: Error, LocalizedError {
    /// Throws when the given file has no parent directory
    case missingParent
    /// Throws if the URL for the local cached file is nil.
    case missingResourceURL
    /// Throws if the resource file doesn't exist.
    case missingFile
    /// Throws when the given file upload is in progress
    case isUploading
    /// Throws when the given file doesn't have uploadID
    case noUploadID
    case fileAlreadyUploaded
    case uploaderNotEnabled
    /// Throws when the file data is not as expected (e.g., nameSignature is nil)
    case invalidFileData
    /// Throws when the existing object can't be retrieved from the given URI
    case objectNotFound
    /// Throws an exception if the object type does not match expectations
    case unexpectedObjectType
    case uploaderIsDisabled
    case cancelled

    public var errorDescription: String? {
        #if os(iOS)
        return Localization.progress_status_upload_failed
        #else
        return "Upload failed"
        #endif
    }
}
