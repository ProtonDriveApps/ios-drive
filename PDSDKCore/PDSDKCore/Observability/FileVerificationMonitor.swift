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
import ProtonCoreObservability

public actor FileVerificationMonitor {
    
    private let environment: ObservabilityEnvProtocol.Type

    public init(environment: ObservabilityEnvProtocol.Type = ObservabilityEnv.self) {
        self.environment = environment
    }
    
    public func reportDownloadVerification(
        result: FileVerificationEvent.Result,
        fileSize: Int64,
        checksumVerified: Bool
    ) {
        let event = ObservabilityEvent.downloadVerificationEvent(
            result: result,
            fileSize: FileVerificationEvent.FileSize(bytes: fileSize),
            checksumVerified: checksumVerified
        )
        ObservabilityEnv.report(event)
    }
    
    public func reportUploadVerification(sha1Provided: Bool) {
        let event = ObservabilityEvent.uploadVerificationEvent(sha1Provided: sha1Provided)
        ObservabilityEnv.report(event)
    }
}
