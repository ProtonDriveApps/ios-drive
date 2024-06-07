//
//  AuthAPI.swift
//  ProtonCore-APIClient - Created on 5/22/20.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

// swiftlint:disable identifier_name

import Foundation
import ProtonCoreNetworking

// Auth API
public struct AuthAPI: APIClient {
    /// base message api path
    static let route: String = "/auth"

    /// user auth post
    static let v_auth: Int = 3
    /// refresh token post
    static let v_auth_refresh: Int = 3
    /// setup auth info post
    static let v_auth_info: Int = 3
    /// get random srp modulus
    static let v_get_auth_modulus: Int = 3
    /// delete auth
    static let v_delete_auth: Int = 3
    /// revoke other tokens
    static let v_revoke_others: Int = 3
    /// submit 2fa code
    static let v_auth_2fa: Int = 3

    struct Key {
        static let clientSecret = "ClientSecret"
        static let responseType = "ResponseType"
        static let userName = "Username"
        static let password = "Password"
        static let hashedPassword = "HashedPassword"
        static let grantType = "GrantType"
        static let redirectUrl = "RedirectURI"
        static let scopes = "Scope"

        static let ephemeral = "ClientEphemeral"
        static let proof = "ClientProof"
        static let session = "SRPSession"
        static let twoFactor = "TwoFactorCode"
    }

    public enum Router: Request {
        case info(username: String)
        case modulus
        case auth(username: String, ephemeral: String, proof: String, session: String)

        public var path: String {
            switch self {
            case .info:
                return route + "/info"
            case .modulus:
                return route + "/modulus"
            case .auth:
                return route + "/v4"
            }
        }

        public var header: [String: Any] {
            return [:]
        }

        public var method: HTTPMethod {
            switch self {
            case .info, .auth:
                return .post
            case .modulus:
                return .get
            }
        }

        public var isAuth: Bool {
            return false
        }

        public var parameters: [String: Any]? {
            switch self {
            case .info(let username):
                let out: [String: Any] = [
                    Key.userName: username
                ]
                return out
            case .modulus:
                return nil
            case .auth(let username, let ephemeral, let proof, let session):
                let out: [String: Any] = [
                    Key.userName: username,
                    Key.ephemeral: ephemeral,
                    Key.proof: proof,
                    Key.session: session
                ]
                return out
            }
        }
    }
}

// swiftlint:enable identifier_name
