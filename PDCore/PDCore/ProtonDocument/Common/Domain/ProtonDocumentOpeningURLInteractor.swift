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

public protocol ProtonDocumentOpeningURLInteractorProtocol {
    func getURL(for nodeIdentifier: NodeIdentifier) throws -> URL
    func getURL(for incomingURL: URL) throws -> URL
}

final class ProtonDocumentOpeningURLInteractor: ProtonDocumentOpeningURLInteractorProtocol {
    private let parser: ProtonDocumentIncomingURLParserProtocol
    private let identifierResource: ProtonDocumentIdentifierRepositoryProtocol
    private let urlFactory: ProtonDocumentURLFactoryProtocol

    init(parser: ProtonDocumentIncomingURLParserProtocol, identifierResource: ProtonDocumentIdentifierRepositoryProtocol, urlFactory: ProtonDocumentURLFactoryProtocol) {
        self.parser = parser
        self.identifierResource = identifierResource
        self.urlFactory = urlFactory
    }

    func getURL(for nodeIdentifier: NodeIdentifier) throws -> URL {
        let identifier = try identifierResource.getIdentifier(from: nodeIdentifier)
        return try urlFactory.makeURL(from: identifier)
    }

    func getURL(for incomingURL: URL) throws -> URL {
        let identifier = try parser.parse(incomingURL)
        return try getURL(for: identifier)
    }
}
