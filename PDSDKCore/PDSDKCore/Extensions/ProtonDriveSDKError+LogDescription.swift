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
import ProtonDriveSDK

extension ProtonDriveSDKError: @retroactive LogDescriptive {
    public var logDescription: String {
        var parts: [String] = [
            "type=\(type)",
            "domain=\(domain.logName)",
            "message=\(message)"
        ]
        if let primaryCode { parts.append("primaryCode=\(primaryCode)") }
        if let secondaryCode { parts.append("secondaryCode=\(secondaryCode)") }
        if let context, !context.isEmpty {
            parts.append("context=\"\(context.truncatedForSDKLog())\"")
        }
        if let inner = innerError {
            parts.append("| inner: " + inner.logDescription)
        }
        return parts.joined(separator: " ")
    }
}

private extension ProtonDriveSDKError.Domain {
    var logName: String {
        switch self {
        case .undefined: return "undefined"
        case .successfulCancellation: return "successfulCancellation"
        case .api: return "api"
        case .network: return "network"
        case .transport: return "transport"
        case .serialization: return "serialization"
        case .cryptography: return "cryptography"
        case .dataIntegrity: return "dataIntegrity"
        case .businessLogic: return "businessLogic"
        case .interop: return "interop"
        }
    }
}

private extension String {
    func truncatedForSDKLog(maxLines: Int = 10, maxChars: Int = 1000) -> String {
        let joined = split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(maxLines)
            .joined(separator: " ")
        guard joined.count > maxChars else { return joined }
        return String(joined.prefix(maxChars)) + "…"
    }
}
