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

public struct ClientCredential: Codable {
    public typealias Scope = [String]
    
    enum CodingKeys: String, CodingKey {
        case UID
        case accessToken
        case refreshToken
        case expiration
        case userName
        case userID
        case scope
    }
    
    public var UID: String
    public var accessToken: String
    public var refreshToken: String
    public var expiration: Date
    public var userName: String
    public var userID: String
    public var scope: Scope
    
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
}
