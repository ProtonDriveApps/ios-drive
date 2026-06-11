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
import ProtonCoreNetworking
import ProtonCoreServices

public enum HttpResilienceRequestType {
    case regularApi
    case storageDownload
    case storageUpload
}

public protocol HttpResilienceConfigurationProvider: Sendable {
    func retryConfiguration(for requestType: HttpResilienceRequestType) -> HttpClientResilience.Configuration
}

public enum DefaultHttpResilienceConfigurationProvider: HttpResilienceConfigurationProvider {
    case instance

    public func retryConfiguration(for requestType: HttpResilienceRequestType) -> HttpClientResilience.Configuration {
        switch requestType {
        case .regularApi: return .forDriveAPICalls
        case .storageUpload, .storageDownload: return .forNonRetriableStorageCalls
        }
    }
}

enum PerformRetryDecision<T> {
    case noRetry(Result<T, NSError>)
    case retryAfter(Duration, previousError: Error?)
    case retryAfterRefreshingCredentials(Error)
}

public enum ParticipateInRetries<T> {
    case retryIfNeeded(Result<T, NSError>)
    case doNotRetry(Result<T, NSError>)
}

public enum HttpClientResilience {

    public struct Configuration {
        fileprivate let maxNumberOfTries: Int
        fileprivate let exponentialBackoffBase: Double
        fileprivate let exponentialBackoffScale: Double
        fileprivate let maxJitterFactor: Double
        fileprivate let retryOn401: Bool

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

        static var forDriveAPICalls: Configuration = .init(
            maxNumberOfTries: 6,
            exponentialBackoffBase: 2.0, // 1.0, 2.0, 4.0, 8.0, 16.0 seconds
            exponentialBackoffScale: 0.5,
            maxJitterFactor: 0.2,
            retryOn401: false // the 401 retries are handled by PMAPIService
        )

        static var forNonRetriableStorageCalls: Configuration = .init(
            maxNumberOfTries: 2,
            exponentialBackoffBase: 5.0, // 5.0, 25.0 seconds
            exponentialBackoffScale: 1.0,
            maxJitterFactor: 0.2,
            retryOn401: true
        )
    }

    public static func performWithResilience(
        configuration: Configuration,
        rateLimitGate: RateLimitGate,
        family: String,
        refreshCredentials: @escaping (Error) async throws -> Void,
        operation: @escaping (Error?) async -> ParticipateInRetries<HttpClientResponse>
    ) async -> Result<HttpClientResponse, NSError> {
        await performWithResilienceRecursive(
            retryCount: 0,
            previousError: nil,
            operation: operation,
            refreshCredentials: refreshCredentials,
            configuration: configuration,
            rateLimitGate: rateLimitGate,
            family: family
        ) { result, retryCount, configuration in
            switch result {
            case .success(let response):
                return await parse(
                    response: response, retryCount: retryCount, configuration: configuration,
                    rateLimitGate: rateLimitGate, family: family
                )
            case .failure(let error):
                return parse(error: error, retryCount: retryCount, configuration: configuration)
            }
        }
    }

    static func performWithResilience(
        configuration: Configuration,
        rateLimitGate: RateLimitGate,
        family: String,
        refreshCredentials: @escaping (Error) async throws -> Void,
        operation: @escaping (Error?) async -> ParticipateInRetries<HttpClientStream>
    ) async -> Result<HttpClientStream, NSError> {
        await performWithResilienceRecursive(
            retryCount: 0,
            previousError: nil,
            operation: operation,
            refreshCredentials: refreshCredentials,
            configuration: configuration,
            rateLimitGate: rateLimitGate,
            family: family
        ) { result, retryCount, configuration in
            switch result {
            case .success(let stream):
                return await parse(
                    stream: stream, retryCount: retryCount, configuration: configuration,
                    rateLimitGate: rateLimitGate, family: family
                )
            case .failure(let error):
                return parse(error: error, retryCount: retryCount, configuration: configuration)
            }
        }
    }

    private static func performWithResilienceRecursive<T>(
        retryCount: Int,
        previousError: Error?,
        operation: @escaping (Error?) async -> ParticipateInRetries<T>,
        refreshCredentials: @escaping (Error) async throws -> Void,
        configuration: Configuration,
        rateLimitGate: RateLimitGate,
        family: String,
        parse: @escaping (Result<T, NSError>, Int, Configuration) async -> PerformRetryDecision<T>
    ) async -> Result<T, NSError> {
        // Park here if any prior request in this family observed a 429. The gate
        // is shared with PDClient's `Client`, so a 429 on either tier delays
        // calls in the same family on the other.
        await rateLimitGate.waitIfNeeded(family: family)
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
                    rateLimitGate: rateLimitGate,
                    family: family,
                    parse: parse
                )

            case .retryAfter(let duration, let proximateError):
                Log.debug("HttpClientResilience retry. Duration: \(duration), retryCount: \(retryCount)",
                          domain: .networking)
                // Local backoff for 5xx / network errors. For 429s the gate already
                // recorded the deadline; the next iteration's `waitIfNeeded` will
                // park the request, and `duration` here is `.zero` (see `commonRetryDecisionLogic`).
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
                    rateLimitGate: rateLimitGate,
                    family: family,
                    parse: parse
                )
            }
        }
    }

    static func parse(
        response: HttpClientResponse,
        retryCount: Int,
        configuration: Configuration,
        rateLimitGate: RateLimitGate,
        family: String
    ) async -> PerformRetryDecision<HttpClientResponse> {
        if let retryDecision = await commonRetryDecisionLogic(
            response, statusCode: response.statusCode, headers: response.headers,
            retryCount: retryCount, configuration: configuration,
            rateLimitGate: rateLimitGate, family: family
        ) {
            return retryDecision
        }

        Log.debug("HttpClientResilience no-200 response but no retry: \(response.statusCode)",
                  domain: .networking)

        return .noRetry(.success(response))
    }

    static func parse(
        stream: HttpClientStream,
        retryCount: Int,
        configuration: Configuration,
        rateLimitGate: RateLimitGate,
        family: String
    ) async -> PerformRetryDecision<HttpClientStream> {
        if let retryDecision = await commonRetryDecisionLogic(
            stream, statusCode: stream.statusCode, headers: stream.headers,
            retryCount: retryCount, configuration: configuration,
            rateLimitGate: rateLimitGate, family: family
        ) {
            return retryDecision
        }

        Log.debug("HttpClientResilience no-200 response but no retry: \(stream.statusCode)",
                  domain: .networking)

        return .noRetry(.success(stream))
    }

    static func parse<T>(
        error: NSError, retryCount: Int, configuration: Configuration
    ) -> PerformRetryDecision<T> {
        guard retryCount < configuration.maxNumberOfTries else {
            return .noRetry(.failure(error))
        }

        let errorCodesIndicatingTimeoutOrNetworkError: Set<URLError.Code> = [
            .unknown,
            .badURL,
            .timedOut,
            .unsupportedURL,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .dnsLookupFailed,
            .httpTooManyRedirects,
            .resourceUnavailable,
            .notConnectedToInternet,
            .redirectToNonExistentLocation,
            .badServerResponse,
            .userCancelledAuthentication,
            .userAuthenticationRequired,
            .zeroByteResource,
            .cannotDecodeRawData,
            .cannotDecodeContentData,
            .cannotParseResponse,
            .appTransportSecurityRequiresSecureConnection,
            .secureConnectionFailed,
            .serverCertificateHasBadDate,
            .serverCertificateUntrusted,
            .serverCertificateHasUnknownRoot,
            .serverCertificateNotYetValid,
            .clientCertificateRejected,
            .clientCertificateRequired,
            .cannotLoadFromNetwork,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed,
            .requestBodyStreamExhausted
        ]

        if let error = error as? URLError, errorCodesIndicatingTimeoutOrNetworkError.contains(error.code) {
            let duration = durationWithJitter(retryCount: retryCount, configuration: configuration)
            return .retryAfter(duration, previousError: error)
        }

        if let error = error as? ResponseError, error.isApiIsBlockedError {
            let duration = durationWithJitter(retryCount: retryCount, configuration: configuration)
            return .retryAfter(duration, previousError: error)
        }

        if error.code == APIErrorCode.potentiallyBlocked {
            let duration = durationWithJitter(retryCount: retryCount, configuration: configuration)
            return .retryAfter(duration, previousError: error)
        }

        Log.debug("HttpClientResilience error received but no retry: \(error.localizedDescription)",
                  domain: .networking)

        return .noRetry(.failure(error))
    }

    static func commonRetryDecisionLogic<T>(
        _ t: T,
        statusCode: Int,
        headers: [(String, [String])],
        retryCount: Int,
        configuration: Configuration,
        rateLimitGate: RateLimitGate,
        family: String,
        now: Date = Date()
    ) async -> PerformRetryDecision<T>? {
        guard retryCount <= configuration.maxNumberOfTries else {
            return .noRetry(.success(t))
        }

        // success!
        if (200...299).contains(statusCode) {
            return .noRetry(.success(t))
        }

        // retry on auth error if the configuration allows
        if configuration.retryOn401,
           statusCode == 401 {
            let previousError = ResponseError(httpCode: 401, responseCode: nil, userFacingMessage: "User logged out", underlyingError: nil)
            return .retryAfterRefreshingCredentials(previousError)
        }

        // 429: feed the shared gate (cross-tier with PDClient) and let the gate
        // do the actual wait at the next iteration's `waitIfNeeded`. We return
        // `.retryAfter(.zero, ...)` so the recursive helper schedules another
        // attempt without adding its own sleep on top of the gate's.
        if statusCode == 429 {
            let retryAfterValue = headers.first { key, _ in
                key.caseInsensitiveCompare("Retry-After") == .orderedSame
            }?.1.first.flatMap { RateLimitGate.parseRetryAfterValue($0, now: now) }
            await rateLimitGate.recordRateLimited(retryAfter: retryAfterValue, family: family, source: family)
            let previousError = ResponseError(
                httpCode: 429, responseCode: nil, userFacingMessage: "Too many requests", underlyingError: nil
            )
            return .retryAfter(.zero, previousError: previousError)
        }

        // retry based on exponential backoff
        if (500...599).contains(statusCode) {
            let previousError = ResponseError(httpCode: statusCode, responseCode: nil, userFacingMessage: "Internal server error", underlyingError: nil)
            let duration = durationWithJitter(retryCount: retryCount, configuration: configuration)
            return .retryAfter(duration, previousError: previousError)
        }

        return nil
    }

    private static func retryAfterValueInSeconds(
        for retryCount: Int, configuration: Configuration
    ) -> Double {
        pow(configuration.exponentialBackoffBase, Double(retryCount)) * configuration.exponentialBackoffScale
    }

    private static func durationWithJitter(retryCount: Int, configuration: Configuration) -> Duration {
        let retryAfterValue = retryAfterValueInSeconds(for: retryCount, configuration: configuration)
        return durationWithJitter(retryAfterValue: retryAfterValue)
    }

    private static func durationWithJitter(retryAfterValue: Double) -> Duration {
        .seconds(retryAfterValue + jitterInSeconds(base: retryAfterValue))
    }

    private static func jitterInSeconds(base: Double) -> Double {
        let minJitter = 0.0
        let maxJitter = 0.2 * base
        return Double.random(in: minJitter...maxJitter)
    }

    // TODO: circuit breaker
}
