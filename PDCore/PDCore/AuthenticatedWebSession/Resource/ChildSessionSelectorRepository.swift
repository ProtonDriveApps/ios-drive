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
import ProtonCoreAuthentication
import ProtonCoreNetworking
import ProtonCoreServices

struct ChildSessionSelectorRequest {
    let childClientID: String
    let isIndependent: Bool
    let payload: Data
}

protocol ChildSessionSelectorRepositoryProtocol {
    func execute(with request: ChildSessionSelectorRequest) async throws -> String
}

enum ChildSessionSelectorRepositoryError: Error {
    case missingCredential
}

final class ChildSessionSelectorRepository: ChildSessionSelectorRepositoryProtocol {
    private let sessionStorage: SessionStore
    private let authenticator: Authenticator

    init(sessionStorage: SessionStore, authenticator: Authenticator) {
        self.sessionStorage = sessionStorage
        self.authenticator = authenticator
    }

    func execute(with request: ChildSessionSelectorRequest) async throws -> String {
        guard let sessionCredential = sessionStorage.sessionCredential else {
            throw ChildSessionSelectorRepositoryError.missingCredential
        }

        let credential = Credential(sessionCredential)
        let useCase = AuthService.ForkSessionUseCase.forChildClientID(request.childClientID, independent: request.isIndependent, payload: request.payload)

        return try await withCheckedThrowingContinuation { continuation in
            authenticator.forkSession(credential, useCase: useCase) { result in
                switch result {
                case let .success(response):
                    continuation.resume(returning: response.selector)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
