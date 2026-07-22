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
import PDClient
import PDCore
import ProtonDriveSDK

public extension ProtonDriveSDKError {
    var isConflictError: Bool {
        self.innerError?.primaryCode == APIErrorCodes.alreadyExists.rawValue
    }

    var isTooManyChildrenError: Bool {
        guard primaryCode != ResponseCode.tooManyChildren.rawValue else { return true }
        guard let innerError else { return false }
        return innerError.isTooManyChildrenError
    }

    var isNestingTooDeepError: Bool {
        guard primaryCode != ResponseCode.nestingTooDeep.rawValue else { return true }
        guard let innerError else { return false }
        return innerError.isNestingTooDeepError
    }

    var isInsufficientQuotaError: Bool {
        guard primaryCode != ResponseCode.insufficientQuota.rawValue else { return true }
        guard let innerError else { return false }
        return innerError.isInsufficientQuotaError
    }

    var isInsufficientSpaceError: Bool {
        guard primaryCode != ResponseCode.insufficientSpace.rawValue else { return true }
        guard let innerError else { return false }
        return innerError.isInsufficientSpaceError
    }

    /// Matches the C# SDK's classification: only connectivity-related transport
    /// and socket errors count as "offline", not every network-domain error.
    var isLikelyOffline: Bool {
        switch domain {
        case .transport:
            switch asHTTPNetworkError?.errorType {
            case .nameResolutionError, .connectionError, .proxyTunnelError:
                return true
            default:
                return false
            }
        case .network:
            switch asSocketNetworkError?.errorType {
            case .networkDown, .networkUnreachable, .notConnected:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    var isCancellationError: Bool {
        guard case .successfulCancellation = domain else { return false }
        return true
    }
}
