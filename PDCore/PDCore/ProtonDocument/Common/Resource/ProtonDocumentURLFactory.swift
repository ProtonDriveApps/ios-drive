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

protocol ProtonDocumentURLFactoryProtocol {
    func makeURL(from identifier: ProtonDocumentIdentifier) throws -> URL
}

enum ProtonDocumentURLFactoryError: Error {
    case invalidHost
    case invalidURL
}

final class ProtonDocumentURLFactory: ProtonDocumentURLFactoryProtocol {
    private let configuration: APIService.Configuration

    init(configuration: APIService.Configuration) {
        self.configuration = configuration
    }

    func makeURL(from identifier: ProtonDocumentIdentifier) throws -> URL {
        guard var urlComponents = URLComponents(string: configuration.baseHost) else {
            throw ProtonDocumentURLFactoryError.invalidHost
        }
        urlComponents.host = "docs." + (urlComponents.host ?? "")
        urlComponents.path = "/doc"
        urlComponents.queryItems = [
            URLQueryItem(name: "volumeId", value: identifier.volumeId),
            URLQueryItem(name: "linkId", value: identifier.linkId),
            URLQueryItem(name: "email", value: identifier.email)
        ]
        guard let url = urlComponents.url else {
            throw ProtonDocumentURLFactoryError.invalidURL
        }
        return url
    }
}
