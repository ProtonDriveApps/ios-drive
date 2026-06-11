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
import ProtonDriveSDK
import PDCore

protocol AdditionalDataLogger {
    func logAdditionalDataInSDKError(
        _ error: Error,
        context: [String: String],
        file: String,
        function: String,
        line: Int
    )
}

extension AdditionalDataLogger {
    /// Additional data may contain sensitive data, don't send to sentry 
    func logAdditionalDataInSDKError(
        _ error: Error,
        context: [String: String],
        file: String,
        function: String,
        line: Int
    ) {
        guard
            let sdkError = error as? ProtonDriveSDKError,
            let additionalErrorData = sdkError.additionalErrorData
        else { return }
        var logContext = LogContext()
        for (key, value) in context {
            logContext[key] = value
        }
        // These errors need to be logged locally
        if let data = additionalErrorData as? ContentSizeMismatchErrorData {
            Log.error(
                "Size mismatch, expected: \(data.expectedSize), uploaded: \(data.uploadedSize)",
                error: nil,
                domain: .sdk,
                context: logContext,
                sendToSentryIfPossible: false,
                file: file,
                function: function,
                line: line
            )
        } else if let data = additionalErrorData as? ChecksumMismatchErrorData {
            Log.error(
                "Checksum mismatch, expected: \(data.expectedChecksum.hexString()), uploaded: \(data.actualChecksum.hexString())",
                error: nil,
                domain: .sdk,
                context: logContext,
                sendToSentryIfPossible: false,
                file: file,
                function: function,
                line: line
            )
        } else if let data = additionalErrorData as? ThumbnailCountMismatchErrorData {
            Log.error(
                "Thumbnail block count mismatch, expected: \(data.expectedBlockCount), uploaded: \(data.uploadedBlockCount)",
                error: nil,
                domain: .sdk,
                context: logContext,
                sendToSentryIfPossible: false,
                file: file,
                function: function,
                line: line
            )
        }
    }
}
