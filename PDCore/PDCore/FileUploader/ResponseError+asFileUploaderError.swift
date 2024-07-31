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

import ProtonCoreServices

extension ResponseError {
    var isNoSpaceOnCloudError: Bool { code == 200002 }
    var isExpiredResource: Bool { (httpCode == 422 && code == 2501) || (httpCode == 404 && code == 2501) }
    var isFeatureDisabled: Bool { httpCode == 424 && code == 2032 }

    var isRetryable: Bool {
        #if os(iOS)
        isExpiredResource ||
        isFeatureDisabled ||
        RetryPolicy.retryable.contains(httpCode) ||
        RetryPolicy.retryable.contains(bestShotAtReasonableErrorCode)
        #else
        isRetryableIncludingInternetIssues
        #endif
    }

    var isRetryableIncludingInternetIssues: Bool {
        // If any of `allUnderlyingErrorCodes` are contained in RetryPolicy.retryableIncludingInternetIssues, we consider the error retryable.
        isExpiredResource ||
        isFeatureDisabled ||
        isApiIsBlockedError ||
        !RetryPolicy.retryableIncludingInternetIssues.isDisjoint(with: allUnderlyingErrorCodes)
    }

    private var allUnderlyingErrorCodes: [Int?] {
        let underlyingErrorCodes = [underlyingError?.httpCode] + (underlyingError?.underlyingErrors.map { $0.httpCode } ?? [])
        return [httpCode, bestShotAtReasonableErrorCode] + underlyingErrorCodes
    }
}

public extension ResponseError {
    var isVerificationError: Bool {
        httpCode == 422 && responseCode == 200501
    }
}
