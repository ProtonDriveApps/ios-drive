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

import Foundation
import ProtonCoreUtilities
import ProtonCoreServices

public protocol CredentialProvider: AnyObject {
    /// Obtaining credential optionally
    func clientCredential() -> ClientCredential?
    /// Obtaining credential or throwing an error
    func getCredential() throws -> ClientCredential
}

public enum CredentialProviderError: Error {
    case missingCredential
}

public class Client {
    public let credentialProvider: CredentialProvider
    public let service: APIService
    public let networking: DriveAPIService
    public let rateLimitGate: RateLimitGate
    /// Maximum number of attempts (initial + retries) for a single logical request.
    /// Mirrors `HttpClientResilience.Configuration.forDriveAPICalls.maxNumberOfTries`.
    public var maxRetryCount: Int = 6
    public var errorMonitor: ErrorMonitor?
    internal let backgroundQueue = DispatchQueue(label: "Client", attributes: .concurrent)

    public init(
        credentialProvider: CredentialProvider,
        service: APIService,
        networking: DriveAPIService,
        rateLimitGate: RateLimitGate
    ) {
        self.credentialProvider = credentialProvider
        self.service = service
        self.networking = networking
        self.rateLimitGate = rateLimitGate
    }

    public func credential() throws -> ClientCredential {
        do {
            let credential = try credentialProvider.getCredential()
            return credential
        } catch {
            #if os(iOS)
            networking.authDelegate?.onAuthenticatedSessionInvalidated(sessionUID: "")
            #endif
            throw error
        }
    }

    public func request<E: Endpoint, Response>(
        _ endpoint: E,
        completionExecutor: CompletionBlockExecutor = .asyncMainExecutor
    ) async throws -> Response where Response == E.Response {
        do {
            let value = try await performRequestHandling429(
                endpoint,
                completionExecutor: completionExecutor,
                attemptsRemaining: maxRetryCount
            )
            return value
        } catch {
            errorMonitor?.monitorWithContext(endpoint, Result<Response, Error>.failure(error))
            throw error
        }
    }

    private func performRequestHandling429<E: Endpoint, Response>(
        _ endpoint: E,
        completionExecutor: CompletionBlockExecutor,
        attemptsRemaining: Int
    ) async throws -> Response where Response == E.Response {
        await rateLimitGate.waitIfNeeded(family: endpoint.rateLimitFamily)
        let (result, response) = await performSingleAttempt(endpoint, completionExecutor: completionExecutor)

        // Not rate-limited → return whatever we got.
        guard let response, response.statusCode == 429 else {
            return try result.get()
        }

        // 429 → update the gate so siblings/successors wait.
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
            .flatMap { RateLimitGate.parseRetryAfterValue($0) }
        await rateLimitGate.recordRateLimited(
            retryAfter: retryAfter,
            family: endpoint.rateLimitFamily,
            source: endpoint.path
        )

        guard attemptsRemaining > 1 else {
            return try result.get()
        }

        return try await performRequestHandling429(
            endpoint,
            completionExecutor: completionExecutor,
            attemptsRemaining: attemptsRemaining - 1
        )
    }

    private func performSingleAttempt<E: Endpoint, Response>(
        _ endpoint: E,
        completionExecutor: CompletionBlockExecutor
    ) async -> (Result<Response, Error>, HTTPURLResponse?) where Response == E.Response {
        await withCheckedContinuation { (continuation: CheckedContinuation<(Result<Response, Error>, HTTPURLResponse?), Never>) in
            networking.request(
                from: endpoint,
                completionExecutor: completionExecutor
            ) { (result: Result<Response, Error>, response: HTTPURLResponse?) in
                continuation.resume(returning: (result, response))
            }
        }
    }

    func request<E: Endpoint, Response>(
        _ endpoint: E,
        completionExecutor: CompletionBlockExecutor = .asyncMainExecutor,
        completion: @escaping (Result<Response, Error>) -> Void
    ) where Response == E.Response {
        Task {
            let result: Result<Response, Error>
            do {
                let value = try await request(endpoint, completionExecutor: completionExecutor)
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            completionExecutor.execute { completion(result) }
        }
    }

    public func performRequest<E: Endpoint, Response>(on endpoint: E) async throws -> Response where Response == E.Response {
        try await request(endpoint, completionExecutor: .immediateExecutor)
    }

    public enum Errors: String, LocalizedError {
        case couldNotObtainCredential
        case invalidResponse
    }
}

public typealias Breadcrumbs = [(String, String)]

extension LocalizedError where Self: RawRepresentable, Self.RawValue == String {
    public var errorDescription: String? {
        "Error: " + formatterError + "."
    }

    private var formatterError: String {
        rawValue
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression, range: rawValue.range(of: rawValue))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

public protocol ErrorWithDetailedMessage: LocalizedError {
    var detailedMessage: String { get }
}

extension Breadcrumbs {
    public static func startCollecting(with breadcrumb: String = #function, in file: String = #fileID) -> Self {
        [(file, breadcrumb)]
    }
    
    public func collect(breadcrumb: String = #function, in file: String = #fileID) -> Self {
        appending((file, breadcrumb))
    }
    
    public func reduceIntoErrorMessage() -> String {
        reduce(into: "\n") { partialResult, element in
            partialResult.append(contentsOf: "\(element.0): \(element.1)\n")
        }
    }
}

// MARK: - typealias
extension Client {
    public typealias VolumeID = Volume.VolumeID
    public typealias ShareID = Share.ShareID
    public typealias LinkID = Link.LinkID
    public typealias FolderID = Link.LinkID
    public typealias FileID = Link.LinkID
    public typealias RevisionID = Revision.RevisionID
}
