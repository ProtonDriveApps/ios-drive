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
import ProtonCoreNetworking

public typealias NetworkingCredential = Credential

public protocol Endpoint: EndpointWithRawResponse {
    associatedtype Response: Codable
}

extension Endpoint {
    var decoder: JSONDecoder {
        JSONDecoder(strategy: .driveImplementationOfDecapitaliseFirstLetter)
    }
}

public protocol EndpointWithRawResponse: Request {
    var request: URLRequest { get }
    var parameters: [String: Any]? { get }
}

extension EndpointWithRawResponse {
    public var path: String {
        guard let url = self.request.url else {
            assert(false, "Request with no URL")
            return ""
        }
        if let parameters = url.query {
            return url.path + "?" + parameters
        }
        return url.path
    }
    
    public var header: [String: Any] {
        self.request.allHTTPHeaderFields ?? [:]
    }
    
    public var method: HTTPMethod {
        switch self.request.httpMethod {
        case "DELETE":  return HTTPMethod.delete
        case "GET":     return HTTPMethod.get
        case "POST":    return HTTPMethod.post
        case "PUT":     return HTTPMethod.put
        default:
            assert(false, "Unknown HTTP method")
            return .get
        }
    }
    
    public var parameters: [String: Any]? {
        guard let data = request.httpBody else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}

public struct ErrorResponse: Codable, CustomStringConvertible, Error {
    var code: Int
    var error: String
    var errorDescription: String

    public var description: String {
        ["Server Error Response \(code)", error, errorDescription].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    public func nsError() -> NSError {
        let userInfo = [NSLocalizedDescriptionKey: self.error,
                        NSLocalizedFailureReasonErrorKey: self.errorDescription]

        return NSError(domain: "PMAuthentication", code: self.code, userInfo: userInfo)
    }
}

public extension NSError {
    convenience init(_ serverError: ErrorResponse) {
        let userInfo = [NSLocalizedDescriptionKey: serverError.error,
                        NSLocalizedFailureReasonErrorKey: serverError.errorDescription]

        self.init(domain: "PMAuthentication", code: serverError.code, userInfo: userInfo)
    }
}
