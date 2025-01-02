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

public struct ProtonDocumentAuthenticatedData {
    public let url: URL
}

final class ProtonDocumentAuthenticatedDataInteractor: ThrowingAsynchronousInteractor {
    private let sessionInteractor: AuthenticatedWebSessionInteractor
    private let urlFactory: ProtonDocumentAuthenticatedURLFactoryProtocol

    init(sessionInteractor: AuthenticatedWebSessionInteractor, urlFactory: ProtonDocumentAuthenticatedURLFactoryProtocol) {
        self.sessionInteractor = sessionInteractor
        self.urlFactory = urlFactory
    }

    func execute(with identifier: ProtonDocumentIdentifier) async throws -> ProtonDocumentAuthenticatedData {
        let sessionData = try await sessionInteractor.execute()
        let url = try urlFactory.makeURL(identifier: identifier, sessionData: sessionData)
        return ProtonDocumentAuthenticatedData(url: url)
    }
}
