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

protocol ProtonDocumentAuthenticatedURLFactoryProtocol {
    func makeURL(identifier: ProtonDocumentIdentifier, sessionData: AuthenticatedWebSessionData) throws -> URL
}

enum ProtonDocumentAuthenticatedURLFactoryError: Error {
    case invalidHost
    case invalidURL
    case invalidNonAuthenticatedURL
}

final class ProtonDocumentAuthenticatedURLFactory: ProtonDocumentAuthenticatedURLFactoryProtocol {
    private let configuration: APIService.Configuration
    private let nonAuthenticatedURLFactory: ProtonDocumentNonAuthenticatedURLFactoryProtocol

    init(configuration: APIService.Configuration, nonAuthenticatedURLFactory: ProtonDocumentNonAuthenticatedURLFactoryProtocol) {
        self.configuration = configuration
        self.nonAuthenticatedURLFactory = nonAuthenticatedURLFactory
    }

    func makeURL(identifier: ProtonDocumentIdentifier, sessionData: AuthenticatedWebSessionData) throws -> URL {
        guard var urlComponents = URLComponents(string: configuration.baseOrigin) else {
            throw ProtonDocumentAuthenticatedURLFactoryError.invalidHost
        }
        guard let host = urlComponents.host, !host.isEmpty else {
            throw ProtonDocumentAuthenticatedURLFactoryError.invalidHost
        }

        urlComponents.host = "docs." + host
        urlComponents.path = "/login"
        let fragment = "selector=\(sessionData.selector)&sk=\(sessionData.key)"
        urlComponents.fragment = fragment
        
        guard let url = urlComponents.url else {
            throw ProtonDocumentAuthenticatedURLFactoryError.invalidURL
        }

        let returnUrl = try makeEncodedReturnURL(with: identifier)
        // `returnUrl` needs to be appended as absolute string, because otherwise iOS performs additional
        // percent encoding which breaks the url for web.
        guard let urlWithRedirection = URL(string: url.absoluteString + "&returnUrl=\(returnUrl)") else {
            throw ProtonDocumentAuthenticatedURLFactoryError.invalidURL
        }

        return urlWithRedirection
    }

    private func makeEncodedReturnURL(with identifier: ProtonDocumentIdentifier) throws -> String {
        let nonAuthenticatedURL = try nonAuthenticatedURLFactory.makeURL(from: identifier)
        let components = URLComponents(url: nonAuthenticatedURL, resolvingAgainstBaseURL: false)
        guard let path = components?.path else {
            throw ProtonDocumentAuthenticatedURLFactoryError.invalidNonAuthenticatedURL
        }
        guard let query = components?.percentEncodedQuery else {
            throw ProtonDocumentAuthenticatedURLFactoryError.invalidNonAuthenticatedURL
        }
        let returnUrl = path + "?" + query
        return returnUrl.addingPercentEncoding(withAllowedCharacters: .uriComponentAllowedSet) ?? ""
    }
}
