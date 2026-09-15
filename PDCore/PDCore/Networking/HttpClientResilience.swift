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

/// Outcome of running one attempt of a resilient operation.
public enum ParticipateInRetries<T> {
    case retryIfNeeded(Result<T, Error>)
    case doNotRetry(Result<T, Error>)
}

/// Decision produced after classifying one attempt's result.
public enum PerformRetryDecision<T> {
    case noRetry(Result<T, Error>)
    case retryAfter(Duration, previousError: Error?)
    case retryAfterRefreshingCredentials(Error)
}

/// Shared retry engine: exponential backoff + jitter over an async `operation`, with a caller-supplied
/// retry classifier (`decide`). The recursive driver is private; two public entry points wrap it:
/// - `performWithResilience` — no `RateLimitGate`, no credential refresh. For callers whose transport
///   already handles rate limiting / auth (e.g. the metadata scan via `PDClient.Client`).
/// - `performRateLimitedWithResilience` — adds the shared `RateLimitGate` (+ `family`) and credential
///   refresh. Used by the SDK HTTP path (see the SDK-typed overloads in PDSDKCore).
public enum HttpClientResilience {

    public struct Configuration {
        public let maxNumberOfTries: Int
        fileprivate let exponentialBackoffBase: Double
        fileprivate let exponentialBackoffScale: Double
        fileprivate let maxJitterFactor: Double
        public let retryOn401: Bool

        public init(maxNumberOfTries: Int,
                    exponentialBackoffBase: Double,
                    exponentialBackoffScale: Double,
                    maxJitterFactor: Double,
                    retryOn401: Bool) {
            self.maxNumberOfTries = maxNumberOfTries
            self.exponentialBackoffBase = exponentialBackoffBase
            self.exponentialBackoffScale = exponentialBackoffScale
            self.maxJitterFactor = maxJitterFactor
            self.retryOn401 = retryOn401
        }

        public static let forDriveAPICalls: Configuration = .init(
            maxNumberOfTries: 6,
            exponentialBackoffBase: 2.0, // 1.0, 2.0, 4.0, 8.0, 16.0 seconds
            exponentialBackoffScale: 0.5,
            maxJitterFactor: 0.2,
            retryOn401: false // the 401 retries are handled by PMAPIService
        )

        public static let forNonRetriableStorageCalls: Configuration = .init(
            maxNumberOfTries: 2,
            exponentialBackoffBase: 5.0, // 5.0, 25.0 seconds
            exponentialBackoffScale: 1.0,
            maxJitterFactor: 0.2,
            retryOn401: true
        )
    }

    /// Resilient retry **without** a rate-limit gate or credential refresh. Suitable for callers whose
    /// underlying transport already handles 429 / auth (e.g. `PDClient.Client` behind the metadata scan).
    public static func performWithResilience<T>(
        configuration: Configuration,
        operation: @escaping (Error?) async -> ParticipateInRetries<T>,
        decide: @escaping (Result<T, Error>, Int, Configuration) async -> PerformRetryDecision<T>
    ) async -> Result<T, Error> {
        await performWithResilienceRecursive(
            retryCount: 0,
            previousError: nil,
            operation: operation,
            refreshCredentials: { _ in },
            configuration: configuration,
            rateLimit: nil,
            parse: decide
        )
    }

    /// Resilient retry that parks on the shared `RateLimitGate` before each attempt and can refresh
    /// credentials on 401. Used by the SDK HTTP path.
    public static func performRateLimitedWithResilience<T>(
        configuration: Configuration,
        rateLimitGate: RateLimitGate,
        family: String,
        refreshCredentials: @escaping (Error) async throws -> Void,
        operation: @escaping (Error?) async -> ParticipateInRetries<T>,
        decide: @escaping (Result<T, Error>, Int, Configuration) async -> PerformRetryDecision<T>
    ) async -> Result<T, Error> {
        await performWithResilienceRecursive(
            retryCount: 0,
            previousError: nil,
            operation: operation,
            refreshCredentials: refreshCredentials,
            configuration: configuration,
            rateLimit: (rateLimitGate, family),
            parse: decide
        )
    }

    private static func performWithResilienceRecursive<T>(
        retryCount: Int,
        previousError: Error?,
        operation: @escaping (Error?) async -> ParticipateInRetries<T>,
        refreshCredentials: @escaping (Error) async throws -> Void,
        configuration: Configuration,
        rateLimit: (gate: RateLimitGate, family: String)?,
        parse: @escaping (Result<T, Error>, Int, Configuration) async -> PerformRetryDecision<T>
    ) async -> Result<T, Error> {
        // Park here if any prior request in this family observed a 429. The gate is shared with PDClient's
        // `Client`, so a 429 on either tier delays calls in the same family on the other. With no gate
        // (the gate-free entry point) there is no wait — the caller's transport handles rate limiting.
        if let (rateLimitGate, family) = rateLimit {
            await rateLimitGate.waitIfNeeded(family: family)
        }
        let retryParticipationDecision = await operation(previousError)

        switch retryParticipationDecision {
        case .doNotRetry(let result):
            return result

        case .retryIfNeeded(let result):

            let retryDecision = await parse(result, retryCount + 1, configuration)

            switch retryDecision {
            case .noRetry(let result):
                return result

            case .retryAfterRefreshingCredentials(let originalError):
                Log.debug("HttpClientResilience credentials refresh. RetryCount: \(retryCount)",
                          domain: .networking)
                do {
                    try await refreshCredentials(originalError)
                } catch is CancellationError {
                    return result
                } catch let refreshError {
                    Log.error("HttpClientResilience credentials refresh failed",
                              error: refreshError, domain: .networking)
                    return result
                }
                return await performWithResilienceRecursive(
                    retryCount: retryCount + 1,
                    previousError: previousError,
                    operation: operation,
                    refreshCredentials: refreshCredentials,
                    configuration: configuration,
                    rateLimit: rateLimit,
                    parse: parse
                )

            case .retryAfter(let duration, let proximateError):
                Log.debug("HttpClientResilience retry. Duration: \(duration), retryCount: \(retryCount)",
                          domain: .networking)
                // Local backoff for 5xx / network errors. For 429s the gate already recorded the deadline;
                // the next iteration's `waitIfNeeded` will park the request, and `duration` here is `.zero`.
                do {
                    try await Task.sleep(for: duration)
                } catch {
                    return result
                }
                return await performWithResilienceRecursive(
                    retryCount: retryCount + 1,
                    previousError: proximateError,
                    operation: operation,
                    refreshCredentials: refreshCredentials,
                    configuration: configuration,
                    rateLimit: rateLimit,
                    parse: parse
                )
            }
        }
    }

    // MARK: - Backoff

    public static func durationWithJitter(retryCount: Int, configuration: Configuration) -> Duration {
        let retryAfterValue = retryAfterValueInSeconds(for: retryCount, configuration: configuration)
        return durationWithJitter(retryAfterValue: retryAfterValue, maxJitterFactor: configuration.maxJitterFactor)
    }

    private static func retryAfterValueInSeconds(
        for retryCount: Int, configuration: Configuration
    ) -> Double {
        pow(configuration.exponentialBackoffBase, Double(retryCount)) * configuration.exponentialBackoffScale
    }

    private static func durationWithJitter(retryAfterValue: Double, maxJitterFactor: Double) -> Duration {
        .seconds(retryAfterValue + jitterInSeconds(base: retryAfterValue, maxJitterFactor: maxJitterFactor))
    }

    private static func jitterInSeconds(base: Double, maxJitterFactor: Double) -> Double {
        let maxJitter = maxJitterFactor * base
        guard maxJitter > 0 else { return 0 }
        return Double.random(in: 0...maxJitter)
    }
}
