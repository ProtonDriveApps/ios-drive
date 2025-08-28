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

public protocol ProtonFileNonAuthenticatedURLFactoryProtocol {
    func makeURL(from identifier: ProtonFileIdentifier) throws -> URL
}

enum ProtonFileNonAuthenticatedURLFactoryError: Error {
    case invalidHost
    case invalidURL
    case invalidFileType
}

final class ProtonFileNonAuthenticatedURLFactory: ProtonFileNonAuthenticatedURLFactoryProtocol {
    private let configuration: APIService.Configuration

    init(configuration: APIService.Configuration) {
        self.configuration = configuration
    }

    func makeURL(from identifier: ProtonFileIdentifier) throws -> URL {
        guard var urlComponents = URLComponents(string: configuration.baseOrigin) else {
            throw ProtonFileNonAuthenticatedURLFactoryError.invalidHost
        }
        let path: String
        switch identifier.type {
        case .doc:
            path = "/doc"
        case .sheet:
            path = "/sheet"
        }

        urlComponents.host = "docs." + (urlComponents.host ?? "")
        urlComponents.path = path
        urlComponents.queryItems = [
            URLQueryItem(name: "mode", value: "open"),
            URLQueryItem(name: "volumeId", value: identifier.volumeId),
            URLQueryItem(name: "linkId", value: identifier.linkId),
            URLQueryItem(name: "email", value: identifier.email)
        ]
        guard let url = urlComponents.url else {
            throw ProtonFileNonAuthenticatedURLFactoryError.invalidURL
        }
        return url
    }
}
