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
    public var errorMonitor: ErrorMonitor?
    internal let backgroundQueue = DispatchQueue(label: "Client", attributes: .concurrent)

    public init(credentialProvider: CredentialProvider, service: APIService, networking: DriveAPIService) {
        self.credentialProvider = credentialProvider
        self.service = service
        self.networking = networking
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

    func request<E: Endpoint, Response>(_ endpoint: E, completionExecutor: CompletionBlockExecutor = .asyncMainExecutor, completion: @escaping (Result<Response, Error>) -> Void) where Response == E.Response {
        networking.request(from: endpoint, completionExecutor: completionExecutor) { [errorMonitor] result in
            errorMonitor?.monitorWithContext(endpoint, result)
            completion(result)
        }
    }
    public func request<E: Endpoint, Response>(_ endpoint: E, completionExecutor: CompletionBlockExecutor = .asyncMainExecutor) async throws -> Response where Response == E.Response {
        return try await withCheckedThrowingContinuation { continuation in
            request(endpoint, completionExecutor: completionExecutor) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
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
