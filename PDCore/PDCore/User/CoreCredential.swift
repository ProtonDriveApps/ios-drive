// Copyright (c) 2023 Proton AG
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
import ProtonCore_Authentication
import ProtonCore_Networking

public struct CoreCredential: Codable {
    typealias Scope = [String]
    
    enum CodingKeys: String, CodingKey {
        case UID
        case accessToken
        case refreshToken
        case expiration
        case userName
        case userID
        case scope
    }
    
    var UID: String
    var accessToken: String
    var refreshToken: String
    var expiration: Date
    var userName: String
    var userID: String
    var scope: Scope
    
    var worksForDrive: Bool {
        scope.contains("drive")
    }
    
    public init(UID: String, accessToken: String, refreshToken: String, expiration: Date, userName: String, userID: String, scope: ClientCredential.Scope) {
        self.UID = UID
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiration = expiration
        self.userName = userName
        self.userID = userID
        self.scope = scope
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.UID = try values.decode(String.self, forKey: .UID)
        self.accessToken = try values.decode(String.self, forKey: .accessToken)
        self.refreshToken = try values.decode(String.self, forKey: .refreshToken)
        self.expiration = try values.decode(Date.self, forKey: .expiration)
        self.userName = (try? values.decode(String.self, forKey: .userName)) ?? ""
        self.userID = (try? values.decode(String.self, forKey: .userID)) ?? ""
        self.scope = try values.decode(Scope.self, forKey: .scope)
    }

    public init(authCredential: AuthCredential, scopes: [String]) {
        self.init(
            UID: authCredential.sessionID,
            accessToken: authCredential.accessToken,
            refreshToken: authCredential.refreshToken,
            expiration: authCredential.expiration,
            userName: authCredential.userName,
            userID: authCredential.userID,
            scope: scopes
        )
    }
}

extension PDCore.CoreCredential {
    init(_ clientCredential: PDClient.ClientCredential) {
        self.UID = clientCredential.UID
        self.accessToken = clientCredential.accessToken
        self.refreshToken = clientCredential.refreshToken
        self.expiration = clientCredential.expiration
        self.userName = clientCredential.userName
        self.userID = clientCredential.userID
        self.scope = clientCredential.scope
    }
}

extension PDClient.ClientCredential {
    init(_ credential: PDCore.CoreCredential) {
        self.init(UID: credential.UID,
                  accessToken: credential.accessToken,
                  refreshToken: credential.refreshToken,
                  expiration: credential.expiration,
                  userName: credential.userName,
                  userID: credential.userID,
                  scope: credential.scope)
    }
}

extension PDCore.CoreCredential {
    public init(_ networkingCredential: Credential) {
        self.UID = networkingCredential.UID
        self.accessToken = networkingCredential.accessToken
        self.refreshToken = networkingCredential.refreshToken
        self.expiration = networkingCredential.expiration
        self.userName = networkingCredential.userName
        self.userID = networkingCredential.userID
        self.scope = networkingCredential.scope
    }
}

extension Credential {
    init(_ coreCredential: PDCore.CoreCredential) {
        self.init(UID: coreCredential.UID,
                  accessToken: coreCredential.accessToken,
                  refreshToken: coreCredential.refreshToken,
                  expiration: coreCredential.expiration,
                  userName: coreCredential.userName,
                  userID: coreCredential.userID,
                  scope: coreCredential.scope)
    }
}
