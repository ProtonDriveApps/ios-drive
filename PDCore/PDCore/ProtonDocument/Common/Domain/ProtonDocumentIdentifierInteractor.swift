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

/// Converts `NodeIdentifier` or `URL` into valid proton doc identifier
public protocol ProtonDocumentIdentifierInteractorProtocol {
    func getIdentifier(for nodeIdentifier: NodeIdentifier) throws -> ProtonDocumentIdentifier
    func getIdentifier(for incomingURL: URL) throws -> ProtonDocumentIdentifier
}

final class ProtonDocumentIdentifierInteractor: ProtonDocumentIdentifierInteractorProtocol {
    private let parser: ProtonDocumentIncomingURLParserProtocol
    private let identifierResource: ProtonDocumentIdentifierRepositoryProtocol

    init(parser: ProtonDocumentIncomingURLParserProtocol, identifierResource: ProtonDocumentIdentifierRepositoryProtocol) {
        self.parser = parser
        self.identifierResource = identifierResource
    }

    func getIdentifier(for nodeIdentifier: NodeIdentifier) throws -> ProtonDocumentIdentifier {
        return try identifierResource.getIdentifier(from: nodeIdentifier)
    }

    func getIdentifier(for incomingURL: URL) throws -> ProtonDocumentIdentifier {
        let identifier = try parser.parse(incomingURL)
        return try getIdentifier(for: identifier)
    }
}
