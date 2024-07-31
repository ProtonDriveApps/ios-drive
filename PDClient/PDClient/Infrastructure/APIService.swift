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
import ProtonCoreEnvironment
import ProtonCoreServices

public typealias URLSessionDelegateCompletion = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
public typealias TrustChallenge = (URLSession, URLAuthenticationChallenge, @escaping URLSessionDelegateCompletion) -> Void

public class APIService {
    public let configuration: Configuration
    public let baseHeadersFactory: BaseHeadersFactory
    
    public init(configuration: Configuration, baseHeadersFactory: BaseHeadersFactory) {
        self.configuration = configuration
        self.baseHeadersFactory = baseHeadersFactory
    }
    
    var baseComponents: URLComponents {
        var urlComponents = URLComponents(string: configuration.host)!
        urlComponents.path = "/drive"
        return urlComponents
    }
    
    public var baseHeaders: [String: String] {
        baseHeadersFactory.makeHeaders()
    }
    
    public func authHeaders(_ credential: ClientCredential) -> [String: String] {
        [
            "Authorization": "Bearer " + credential.accessToken,
            "x-pm-uid": credential.UID
        ]
    }

    public func url(of path: String, parameters: [URLQueryItem]? = nil) -> URL {
        var urlComponents = self.baseComponents
        urlComponents.queryItems = parameters
        guard let url = urlComponents.url else {
            fatalError("Could not create URL from components")
        }
        return url.appendingPathComponent(path)
    }

    func url(of path: String, queries: [URLQueryItem]?) -> URL {
        if let queries, !queries.isEmpty {
            return url(of: path, parameters: queries)
        } else {
            return url(of: path)
        }
    }
}

public extension APIService {
    struct Configuration {
        private static let apiPrefix = "drive-api."

        public let environment: Environment
        public let clientVersion: String
        /// API host path
        public let host: String
        /// Base host path (without API prefix)
        public let baseHost: String

        public init(environment: Environment, clientVersion: String) {
            self.environment = environment
            self.clientVersion = clientVersion
            self.host = environment.doh.defaultHost

            if host.contains(Configuration.apiPrefix) {
                baseHost = host.replacingOccurrences(of: Configuration.apiPrefix, with: "")
            } else {
                baseHost = host
            }
        }
    }
}
