// Copyright (c) 2024 Proton AG
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

protocol ProtonFileAuthenticatedURLFactoryProtocol {
    func makeURL(identifier: ProtonFileIdentifier, sessionData: AuthenticatedWebSessionData) throws -> URL
}

enum ProtonFileAuthenticatedURLFactoryError: Error {
    case invalidHost
    case invalidURL
    case invalidNonAuthenticatedURL
}

final class ProtonFileAuthenticatedURLFactory: ProtonFileAuthenticatedURLFactoryProtocol {
    private let configuration: APIService.Configuration
    private let nonAuthenticatedURLFactory: ProtonFileNonAuthenticatedURLFactoryProtocol

    init(configuration: APIService.Configuration, nonAuthenticatedURLFactory: ProtonFileNonAuthenticatedURLFactoryProtocol) {
        self.configuration = configuration
        self.nonAuthenticatedURLFactory = nonAuthenticatedURLFactory
    }

    func makeURL(identifier: ProtonFileIdentifier, sessionData: AuthenticatedWebSessionData) throws -> URL {
        guard var urlComponents = URLComponents(string: configuration.baseOrigin) else {
            throw ProtonFileAuthenticatedURLFactoryError.invalidHost
        }
        guard let host = urlComponents.host, !host.isEmpty else {
            throw ProtonFileAuthenticatedURLFactoryError.invalidHost
        }

        urlComponents.host = "docs." + host
        urlComponents.path = "/login"
        let fragment = "selector=\(sessionData.selector)&sk=\(sessionData.key)"
        urlComponents.fragment = fragment
        
        guard let url = urlComponents.url else {
            throw ProtonFileAuthenticatedURLFactoryError.invalidURL
        }

        let returnUrl = try makeEncodedReturnURL(with: identifier)
        // `returnUrl` needs to be appended as absolute string, because otherwise iOS performs additional
        // percent encoding which breaks the url for web.
        guard let urlWithRedirection = URL(string: url.absoluteString + "&returnUrl=\(returnUrl)") else {
            throw ProtonFileAuthenticatedURLFactoryError.invalidURL
        }

        return urlWithRedirection
    }

    private func makeEncodedReturnURL(with identifier: ProtonFileIdentifier) throws -> String {
        let nonAuthenticatedURL = try nonAuthenticatedURLFactory.makeURL(from: identifier)
        let components = URLComponents(url: nonAuthenticatedURL, resolvingAgainstBaseURL: false)
        guard let path = components?.path else {
            throw ProtonFileAuthenticatedURLFactoryError.invalidNonAuthenticatedURL
        }
        guard let query = components?.percentEncodedQuery else {
            throw ProtonFileAuthenticatedURLFactoryError.invalidNonAuthenticatedURL
        }
        let returnUrl = path + "?" + query
        return returnUrl.addingPercentEncoding(withAllowedCharacters: .uriComponentAllowedSet) ?? ""
    }
}
