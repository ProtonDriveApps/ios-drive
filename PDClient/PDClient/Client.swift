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
    public let credentialProvider: CredentialProvider?
    public let service: APIService
    public let networking: DriveAPIService
    public var errorMonitor: ErrorMonitor?

    public init(credentialProvider: CredentialProvider, service: APIService, networking: DriveAPIService) {
        self.credentialProvider = credentialProvider
        self.service = service
        self.networking = networking
    }

    // swiftlint:disable:next todo
    // TODO: Make credential provider non optional
    func credential() throws -> ClientCredential {
        guard let credentialProvider else {
            throw Errors.couldNotObtainCredential
        }
        return try credentialProvider.getCredential()
    }

    func request<E: Endpoint, Response>(_ endpoint: E, completion: @escaping (Result<Response, Error>) -> Void) where Response == E.Response {
        networking.request(from: endpoint) { [errorMonitor] result in
            errorMonitor?.monitorWithContext(endpoint, result)
            completion(result)
        }
    }
    public func request<E: Endpoint, Response>(_ endpoint: E) async throws -> Response where Response == E.Response {
        return try await withCheckedThrowingContinuation { continuation in
            request(endpoint) { result in
                switch result {
                case .success(let folder):
                    continuation.resume(returning: folder)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public enum Errors: String, LocalizedError {
        case couldNotObtainCredential
    }
}

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

// MARK: - typealias
extension Client {
    public typealias VolumeID = Volume.VolumeID
    public typealias ShareID = Share.ShareID
    public typealias LinkID = Link.LinkID
    public typealias FolderID = Link.LinkID
    public typealias FileID = Link.LinkID
    public typealias RevisionID = Revision.RevisionID
}
