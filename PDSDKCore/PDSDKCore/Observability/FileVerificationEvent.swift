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
import ProtonCoreObservability

extension ObservabilityEvent where Payload == PayloadWithLabels<FileVerificationEvent.Labels> {
    public static func downloadVerificationEvent(
        result: FileVerificationEvent.Result,
        fileSize: FileVerificationEvent.FileSize,
        checksumVerified: Bool
    ) -> Self {
        .init(
            name: "drive_download_verifier_attempts_total",
            labels: .init(result: result, fileSize: fileSize, checksumVerified: checksumVerified),
            version: .v2
        )
    }
}

public enum FileVerificationEvent {
    
    public struct Labels: Encodable, Equatable {
        public let result: Result
        public let fileSize: FileSize
        public let checksumVerified: String

        public init(result: Result, fileSize: FileSize, checksumVerified: Bool) {
            self.result = result
            self.fileSize = fileSize
            self.checksumVerified = checksumVerified ? "true" : "false"
        }
    }
    
    public enum Result: String, Encodable {
        case success
        case failure
        case skipped
    }
    
    public enum FileSize: String, Encodable {
        case `2**10` = "2**10"
        case `2**20` = "2**20"
        case `2**22` = "2**22"
        case `2**25` = "2**25"
        case `2**30` = "2**30"
        case xxxxl = "xxxxl"
        
        public init(bytes: Int64) {
            switch bytes {
            case ...1_024:         // 2^10
                self = .`2**10`
            case ...1_048_576:     // 2^20
                self = .`2**20`
            case ...4_194_304:     // 2^22
                self = .`2**22`
            case ...33_554_432:    // 2^25
                self = .`2**25`
            case ...1_073_741_824: // 2^30
                self = .`2**30`
            default:
                self = .xxxxl
            }
        }
    }
}
