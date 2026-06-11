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

extension ObservabilityEvent where Payload == PayloadWithLabels<UploadVerificationEvent.Labels> {
    public static func uploadVerificationEvent(
        sha1Provided: Bool
    ) -> Self {
        .init(
            name: "drive_upload_verifier_attempts_total",
            labels: .init(sha1Provided: sha1Provided),
            version: .v1
        )
    }
}

public enum UploadVerificationEvent {
    
    public struct Labels: Encodable, Equatable {
        public let sha1Provided: String
        
        public init(sha1Provided: Bool) {
            self.sha1Provided = sha1Provided ? "true" : "false"
        }
    }
}
