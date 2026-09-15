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
import ProtonCoreNetworking

/// Retries a scan API call on transient failures with exponential backoff via the shared resilience
/// engine. No `RateLimitGate` is used here: the underlying `PDClient.Client` already handles 429s a
/// layer down. Shared by the v1 tree scan (`ScanNodeOperation`) and the v2 scan.
enum ScanRetry {
    static func perform<T>(
        configuration: HttpClientResilience.Configuration = .forDriveAPICalls,
        _ call: @escaping () async throws -> T
    ) async throws -> T {
        let result: Result<T, Error> = await HttpClientResilience.performWithResilience(
            configuration: configuration,
            operation: { _ in
                do {
                    return .retryIfNeeded(.success(try await call()))
                } catch {
                    return .retryIfNeeded(.failure(error))
                }
            },
            decide: { result, retryCount, configuration in
                guard case let .failure(error) = result else {
                    return .noRetry(result)
                }
                guard retryCount < configuration.maxNumberOfTries, isRetryable(error) else {
                    return .noRetry(result)
                }
                let duration = HttpClientResilience.durationWithJitter(retryCount: retryCount, configuration: configuration)
                return .retryAfter(duration, previousError: error)
            }
        )
        return try result.get()
    }

    /// Transient transport/server failures worth retrying (timeouts, connection issues, 408, 5xx).
    /// 429 is intentionally excluded — `Client` already handles rate limiting via `RateLimitGate`.
    static func isRetryable(_ error: Error) -> Bool {
        !RetryPolicy.retryableIncludingInternetIssues.isDisjoint(with: comparableCodes(of: error))
    }

    private static func comparableCodes(of error: Error) -> Set<Int> {
        guard let responseError = error as? ResponseError else {
            return [(error as NSError).code]
        }
        var codes: Set<Int> = [responseError.bestShotAtReasonableErrorCode]
        if let httpCode = responseError.httpCode {
            codes.insert(httpCode)
        }
        if let underlyingError = responseError.underlyingError {
            codes.insert(underlyingError.code)
            underlyingError.underlyingErrors
                .flatMap { comparableCodes(of: $0) }
                .forEach { codes.insert($0) }
        }
        return codes
    }
}
