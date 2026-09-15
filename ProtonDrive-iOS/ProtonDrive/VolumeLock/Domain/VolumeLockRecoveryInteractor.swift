// Copyright (c) 2026 Proton AG
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
import PDCore

protocol VolumeLockRecoveryInteractorProtocol {
    func execute() async throws -> URL
}

enum VolumeLockRecoveryInteractorError: Error {
    case invalidHost
    case invalidURL
}

/// Forks an authenticated web session and builds the account login hand-off URL for volume recovery.
final class VolumeLockRecoveryInteractor: VolumeLockRecoveryInteractorProtocol {
    private let webSessionInteractor: AuthenticatedWebSessionInteractorProtocol
    private let configuration: APIService.Configuration

    init(
        webSessionInteractor: AuthenticatedWebSessionInteractorProtocol,
        configuration: APIService.Configuration
    ) {
        self.webSessionInteractor = webSessionInteractor
        self.configuration = configuration
    }

    func execute() async throws -> URL {
        let sessionData = try await webSessionInteractor.execute(type: .webDrive)
        return try makeURL(sessionData: sessionData)
    }

    private func makeURL(sessionData: AuthenticatedWebSessionData) throws -> URL {
        guard var urlComponents = URLComponents(string: configuration.baseOrigin) else {
            throw VolumeLockRecoveryInteractorError.invalidHost
        }
        guard let host = urlComponents.host, !host.isEmpty else {
            throw VolumeLockRecoveryInteractorError.invalidHost
        }

        urlComponents.host = "drive." + host
        urlComponents.path = "/login"
        urlComponents.fragment = "selector=\(sessionData.selector)&sk=\(sessionData.key)"

        guard let url = urlComponents.url else {
            throw VolumeLockRecoveryInteractorError.invalidURL
        }

        return url
    }
}
