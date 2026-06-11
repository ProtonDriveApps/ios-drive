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

public struct AuthenticatedWebSessionData: Equatable {
    public let selector: String
    public let key: String
}

public enum ForkSessionType: String {
    case protonFile = "web-docs"
    case blackFriday = "WebAccountLite"
}

public protocol AuthenticatedWebSessionInteractorProtocol {
    func execute(type: ForkSessionType) async throws -> AuthenticatedWebSessionData
}

/// Fork session
public final class AuthenticatedWebSessionInteractor: AuthenticatedWebSessionInteractorProtocol {
    private let sessionStore: SessionStore
    private let selectorRepository: ChildSessionSelectorRepositoryProtocol
    private let encryptionResource: AESGCMEncryptionResource
    private let encodingResource: EncodingResource

    public init(
        sessionStore: SessionStore,
        selectorRepository: ChildSessionSelectorRepositoryProtocol,
        encryptionResource: AESGCMEncryptionResource,
        encodingResource: EncodingResource
    ) {
        self.sessionStore = sessionStore
        self.selectorRepository = selectorRepository
        self.encryptionResource = encryptionResource
        self.encodingResource = encodingResource
    }

    public func execute(type: ForkSessionType) async throws -> AuthenticatedWebSessionData {
        // In web's context, the `userPassphrase` AKA `mailboxPassword` is referred to as `keyPassword` or `user's key password`
        let userPassphrase = try sessionStore.getUserPassphrase()
        let payloadDictionary = [
            "type": "default",
            "keyPassword": userPassphrase
        ]
        let payloadData = try encodingResource.encodeIntoJson(payloadDictionary)
        let encryptedPayload = try encryptionResource.encrypt(data: payloadData)
        let request = ChildSessionSelectorRequest(childClientID: type.rawValue, isIndependent: false, payload: encryptedPayload.encryptedData)
        let selector = try await selectorRepository.execute(with: request)
        let key = encryptedPayload.key.base64URLEncodedString()
        return AuthenticatedWebSessionData(selector: selector, key: key)
    }
}
