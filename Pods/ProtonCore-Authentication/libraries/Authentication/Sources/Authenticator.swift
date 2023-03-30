//
//  Authenticator.swift
//  ProtonCore-Authentication - Created on 19/02/2020.
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

import GoLibs
import Foundation
import ProtonCore_APIClient
import ProtonCore_DataModel
import ProtonCore_Networking
import ProtonCore_Services

#if canImport(OpenPGP)
import ThisModuleMustNotHaveOpenPGPLinked
#endif

public class Authenticator: NSObject, AuthenticatorInterface {
    
    public typealias Errors = AuthErrors
    public typealias Completion = (Result<Status, AuthErrors>) -> Void
    
    public enum Status {
        case ask2FA(TwoFactorContext)
        case newCredential(Credential, PasswordMode)
        case updatedCredential(Credential)
    }
    
    public var apiService: APIService!
    public init(api: APIService) {
        self.apiService = api
        super.init()
    }
    
    // we do not want this to be ever used
    override private init() { }

    /// Clear login, when previously unauthenticated
    public func authenticate(username: String, password PASSWORD: String, challenge: ChallengeProperties?, srpAuth: SrpAuth? = nil, completion: @escaping Completion) {
        // 1. auth info request
        let authClient = AuthService(api: self.apiService)
        authClient.info(username: username) { (response) in
            if let responseError = response.error {
                completion(.failure(.from(responseError)))
                return
            }
            
            // guard let response
            guard let salt = response.salt,
                  let signedModulus = response.modulus,
                  let serverEphemeral = response.serverEphemeral,
                  let srpSession = response.srpSession
            else {
                return completion(.failure(Errors.emptyAuthInfoResponse))
            }

            // 2. build SRP things
            do {
                let passSlice = PASSWORD.data(using: .utf8)
                guard let auth = srpAuth ?? SrpAuth.init(response.version,
                                              username: username,
                                              password: passSlice,
                                              b64salt: salt,
                                              signedModulus: signedModulus,
                                              serverEphemeral: serverEphemeral) else
                {
                    return completion(.failure(Errors.emptyServerSrpAuth))
                }
                
                // client SRP
                let srpClient = try auth.generateProofs(2048)
                guard let clientEphemeral = srpClient.clientEphemeral,
                      let clientProof = srpClient.clientProof,
                      let expectedServerProof = srpClient.expectedServerProof else
                {
                    return completion(.failure(Errors.emptyClientSrpAuth))
                }
                
                // 3. auth request
                authClient.auth(username: username, ephemeral: clientEphemeral, proof: clientProof, session: srpSession, challenge: challenge) { (result) in
                    switch result {
                    case .failure(let responseError):
                        completion(.failure(.from(responseError)))
                    case .success(let authResponse):
                        
                        guard expectedServerProof == Data(base64Encoded: authResponse.serverProof) else {
                            return completion(.failure(Errors.wrongServerProof))
                        }
                        // are we done yet or need 2FA?
                        if authResponse._2FA.enabled == .off {
                            let credential = Credential(res: authResponse, userName: username, userID: authResponse.userID)
                            self.apiService.setSessionUID(uid: credential.UID)
                            completion(.success(.newCredential(credential, authResponse.passwordMode)))
                        } else if authResponse._2FA.enabled.contains(.totp) {
                            let credential = Credential(res: authResponse, userName: username, userID: authResponse.userID)
                            self.apiService.setSessionUID(uid: credential.UID)
                            let context = (credential, authResponse.passwordMode)
                            completion(.success(.ask2FA(context)))
                        } else if authResponse._2FA.enabled.contains(.webAuthn) {
                            completion(.failure(Errors.notImplementedYet("WebAuthn not implemented yet")))
                        } else {
                            completion(.failure(Errors.notImplementedYet("Unknown 2FA method required")))
                        }
                    }
                }
            } catch let parsingError {
                return completion(.failure(.parsingError(parsingError)))
            }
        }
    }
    
    /// Continue clear login flow with 2FA code
    public func confirm2FA(_ twoFactorCode: String,
                           context: TwoFactorContext, completion: @escaping Completion)  {
        var route = AuthService.TwoFAEndpoint(code: twoFactorCode)
        route.auth = AuthCredential(context.credential)
        self.apiService.perform(request: route) { (_, result: Result<AuthService.TwoFAResponse, ResponseError>) in
            switch result {
            case .failure(let responseError):
                completion(.failure(.from(responseError)))
            case .success(let response):
                var credential = context.credential
                credential.scopes = response.scopes
                completion(.success(.newCredential(credential, context.passwordMode)))
            }
        }
    }
    
    // Refresh expired access token using refresh token
    public func refreshCredential(_ oldCredential: Credential, completion: @escaping Completion) {
        self.apiService.refreshCredential(oldCredential) { (result: Result<Credential, ResponseError>) in
            switch result {
            case .failure(let responseError):
                completion(.failure(.from(responseError)))
            case .success(let credential):
                completion(.success(.updatedCredential(credential)))
            }
        }
    }

    public func checkAvailableUsernameWithoutSpecifyingDomain(
        _ username: String, completion: @escaping (Result<(), AuthErrors>) -> Void
    ) {
        let route = AuthService.UserAvailableWithoutSpecifyingDomainEndpoint(username: username)
        
        self.apiService.perform(request: route) { (_, result: Result<AuthService.UserAvailableResponse, ResponseError>) in
            completion(result.map { _ in () }.mapError { AuthErrors.from($0) })
        }
    }
    
    public func checkAvailableUsernameWithinDomain(
        _ username: String, domain: String, completion: @escaping (Result<(), AuthErrors>) -> Void
    ) {
        let route = AuthService.UserAvailableWithinDomainEndpoint(username: username, domain: domain)
        self.apiService.perform(request: route) { (_, result: Result<AuthService.UserAvailableResponse, ResponseError>) in
            completion(result.map { _ in () }.mapError { AuthErrors.from($0) })
        }
    }
    
    public func checkAvailableExternal(_ email: String, completion: @escaping (Result<(), AuthErrors>) -> Void) {
        let route = AuthService.UserAvailableExternalEndpoint(email: email)
        
        self.apiService.perform(request: route) { (_, result: Result<AuthService.UserAvailableExternalResponse, ResponseError>) in
            completion(result.map { _ in () }.mapError { AuthErrors.from($0) })
        }
    }

    public func setUsername(_ credential: Credential? = nil, username: String, completion: @escaping (Result<(), AuthErrors>) -> Void) {
        var route = AuthService.SetUsernameEndpoint(username: username)
        if let auth = credential {
            route.auth = AuthCredential(auth)
        }
        self.apiService.perform(request: route) { (_, result: Result<AuthService.SetUsernameResponse, ResponseError>) in
            completion(result.map { _ in () }.mapError { AuthErrors.from($0) })
        }
    }

    public func createAddress(_ credential: Credential? = nil,
                              domain: String,
                              displayName: String? = nil,
                              signature: String? = nil,
                              completion: @escaping (Result<Address, AuthErrors>) -> Void) {
        var route = AuthService.CreateAddressEndpoint(domain: domain, displayName: displayName, signature: signature)
        if let auth = credential {
            route.auth = AuthCredential(auth)
        }
        self.apiService.perform(request: route) { (_, result: Result<AuthService.CreateAddressEndpointResponse, ResponseError>) in
            switch result {
            case .failure(let responseError):
                completion(.failure(.from(responseError)))
            case let .success(data):
                completion(.success(data.address))
            }
        }
    }
    
    public func createUser(userParameters: UserParameters, completion: @escaping (Result<(), AuthErrors>) -> Void) {
        let route = AuthService.CreateUserEndpoint(userParameters: userParameters)
        self.apiService.perform(request: route, response: Response()) { (_, response) in
            if let responseError = response.error {
                completion(.failure(.from(responseError)))
            } else {
                completion(.success(()))
            }
        }
    }

    public func createExternalUser(externalUserParameters: ExternalUserParameters, completion: @escaping (Result<(), AuthErrors>) -> Void) {
        let route = AuthService.CreateExternalUserEndpoint(externalUserParameters: externalUserParameters)
        self.apiService.perform(request: route, response: Response()) { (_, response) in
            if let responseError = response.error {
                completion(.failure(.from(responseError)))
            } else {
                completion(.success(()))
            }
        }
    }

    public func getUserInfo(_ credential: Credential? = nil, completion: @escaping (Result<User, AuthErrors>) -> Void) {
        var route = AuthService.UserInfoEndpoint()
        if let auth = credential {
            route.auth = AuthCredential(auth)
        }
        self.apiService.perform(request: route, decodableCompletion: mapValueAndError(completion) { (response: AuthService.UserResponse) in
            response.user
        })
    }
    
    public func getAddresses(_ credential: Credential? = nil, completion: @escaping (Result<[Address], AuthErrors>) -> Void) {
        var route = AuthService.AddressEndpoint()
        if let auth = credential {
            route.auth = AuthCredential(auth)
        }
        self.apiService.perform(request: route, decodableCompletion: mapValueAndError(completion) { (response: AuthService.AddressesResponse) in
            response.addresses
        })
    }
    
    public func getKeySalts(_ credential: Credential? = nil, completion: @escaping (Result<[KeySalt], AuthErrors>) -> Void) {
        var route = AuthService.KeySaltsEndpoint()
        if let auth = credential {
            route.auth = AuthCredential(auth)
        }
        self.apiService.perform(request: route, decodableCompletion: mapValueAndError(completion) { (response: AuthService.KeySaltsResponse) in
            response.keySalts
        })
    }
    
    public func forkSession(_ credential: Credential? = nil, completion: @escaping (Result<AuthService.ForkSessionResponse, AuthErrors>) -> Void) {
        var route = AuthService.ForkSessionEndpoint()
        if let auth = credential {
            route.auth = AuthCredential(auth)
        }
        self.apiService.perform(request: route, decodableCompletion: mapError(completion))
    }
    
    public func closeSession(_ credential: Credential? = nil, completion: @escaping (Result<AuthService.EndSessionResponse, AuthErrors>) -> Void) {
        var route = AuthService.EndSessionEndpoint()
        if let auth = credential {
            route.auth = AuthCredential(auth)
        }
        self.apiService.perform(request: route, decodableCompletion: mapError(completion))
    }

    public func getRandomSRPModulus(completion: @escaping (Result<AuthService.ModulusEndpointResponse, AuthErrors>) -> Void) {
        let route = AuthService.ModulusEndpoint()
        self.apiService.perform(request: route, decodableCompletion: mapError(completion))
    }
    
    private func mapValueAndError<T, S>(_ completion: @escaping (Result<T, AuthErrors>) -> Void,
                                        _ f: @escaping (S) -> T) -> (URLSessionDataTask?, Result<S, ResponseError>) -> Void {
        return { (_, result: Result<S, ResponseError>) -> Void in
            completion(result.map(f).mapError {
                $0.isApiIsBlockedError ? AuthErrors.apiMightBeBlocked(message: $0.networkResponseMessageForTheUser, originalError: $0) : .networkingError($0)
            })
        }
    }
    
    private func mapError<T>(_ completion: @escaping (Result<T, AuthErrors>) -> Void) -> (URLSessionDataTask?, Result<T, ResponseError>) -> Void {
        return { (_, result: Result<T, ResponseError>) in
            completion(result.mapError {
                $0.isApiIsBlockedError ? AuthErrors.apiMightBeBlocked(message: $0.networkResponseMessageForTheUser, originalError: $0) : .networkingError($0)
            })
        }
    }
}

@available(*, deprecated, message: "Use AuthDelegateHelper instead, it provides more robust API")
public enum RefreshAccessToken {

    public static func callAsFunction(
        credential: Credential, using api: APIService, completion: @escaping (Result<Credential, ResponseError>) -> Void
    ) {
        refresh(credential: credential, using: Authenticator(api: api), completion: completion)
    }

    public static func callAsFunction(
        credential: Credential, using authenticator: Authenticator, completion: @escaping (Result<Credential, ResponseError>) -> Void
    ) {
        refresh(credential: credential, using: authenticator, completion: completion)
    }

    private static func refresh(
        credential: Credential, using authenticator: Authenticator, completion: @escaping (Result<Credential, ResponseError>) -> Void
    ) {
        authenticator.apiService.refreshCredential(credential, completion: completion)
    }

}
