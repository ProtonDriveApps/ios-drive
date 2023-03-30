//
//  SignupService.swift
//  ProtonCore-Login - Created on 11/03/2021.
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

// swiftlint:disable function_parameter_count

import Foundation
import ProtonCore_Crypto
import ProtonCore_APIClient
import ProtonCore_Authentication
import ProtonCore_Authentication_KeyGeneration
import ProtonCore_DataModel
import ProtonCore_Log
import ProtonCore_Networking
import ProtonCore_Services
import ProtonCore_Utilities
import ProtonCore_Foundations

public protocol Signup {

    func requestValidationToken(email: String, completion: @escaping (Result<Void, SignupError>) -> Void)
    func checkValidationToken(email: String, token: String, completion: @escaping (Result<Void, SignupError>) -> Void)
    
    func createNewUsernameAccount(userName: String, password: String, email: String?, phoneNumber: String?, completion: @escaping (Result<(), SignupError>) -> Void)
    func createNewInternalAccount(userName: String, password: String, email: String?, phoneNumber: String?, domain: String, completion: @escaping (Result<(), SignupError>) -> Void)
    func createNewExternalAccount(email: String, password: String, verifyToken: String, tokenType: String, completion: @escaping (Result<(), SignupError>) -> Void)
    func validateEmailServerSide(email: String, completion: @escaping (Result<Void, SignupError>) -> Void)
    func validatePhoneNumberServerSide(number: String, completion: @escaping (Result<Void, SignupError>) -> Void)
}

public class SignupService: Signup {
    private let apiService: APIService
    private let authenticator: Authenticator
    private let clientApp: ClientApp

    // MARK: Public interface

    public init(api: APIService, clientApp: ClientApp) {
        self.apiService = api
        self.authenticator = Authenticator(api: apiService)
        self.clientApp = clientApp
    }

    public func requestValidationToken(email: String, completion: @escaping (Result<Void, SignupError>) -> Void) {
        let route = UserAPI.Router.code(type: .email, receiver: email)
        apiService.perform(request: route, response: Response()) { (_, response) in
            DispatchQueue.main.async {
                if response.responseCode != APIErrorCode.responseOK {
                    if let error = response.error {
                        completion(.failure(SignupError.generic(
                            message: error.networkResponseMessageForTheUser,
                            code: error.bestShotAtReasonableErrorCode,
                            originalError: error
                        )))
                    } else {
                        completion(.failure(SignupError.validationTokenRequest))
                    }
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    public func checkValidationToken(email: String, token: String, completion: @escaping (Result<Void, SignupError>) -> Void) {
        let token = HumanVerificationToken(type: .email, token: token, input: email)
        let route = UserAPI.Router.check(token: token)
        apiService.perform(request: route, response: Response()) { (_, response) in
            DispatchQueue.main.async {
                if response.responseCode != APIErrorCode.responseOK {
                    if response.responseCode == 2500 {
                        completion(.failure(SignupError.emailAddressAlreadyUsed))
                    // TODO: are we checking the right error here?
                    } else if let error = response.error, error.responseCode == 12087 {
                        completion(.failure(SignupError.invalidVerificationCode(message: error.localizedDescription)))
                    } else {
                        if let error = response.error {
                            completion(.failure(SignupError.generic(
                                message: error.networkResponseMessageForTheUser,
                                code: error.bestShotAtReasonableErrorCode,
                                originalError: error
                            )))
                        } else {
                            completion(.failure(SignupError.validationToken))
                        }
                    }
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    public func createNewUsernameAccount(userName: String, password: String, email: String?, phoneNumber: String?, completion: @escaping (Result<(), SignupError>) -> Void) {
        getRandomSRPModulus { result in
            switch result {
            case .success(let modulus):
                self.createUser(userName: userName, password: password, email: email, phoneNumber: phoneNumber, modulus: modulus, domain: nil, completion: completion)
            case .failure(let error):
                return completion(.failure(error))
            }
        }
    }
    
    public func createNewInternalAccount(userName: String, password: String, email: String?, phoneNumber: String?, domain: String, completion: @escaping (Result<(), SignupError>) -> Void) {
        getRandomSRPModulus { result in
            switch result {
            case .success(let modulus):
                self.createUser(userName: userName, password: password, email: email, phoneNumber: phoneNumber, modulus: modulus, domain: domain, completion: completion)
            case .failure(let error):
                return completion(.failure(error))
            }
        }
    }

    public func createNewExternalAccount(email: String, password: String, verifyToken: String, tokenType: String, completion: @escaping (Result<(), SignupError>) -> Void) {
        getRandomSRPModulus { result in
            switch result {
            case .success(let modulus):
                self.createExternalUser(email: email, password: password, modulus: modulus, verifyToken: verifyToken, tokenType: tokenType, completion: completion)
            case .failure(let error):
                return completion(.failure(error))
            }
        }
    }
    
    public func validateEmailServerSide(email: String, completion: @escaping (Result<Void, SignupError>) -> Void) {
        let route = UserAPI.Router.validateEmail(email: email)
        apiService.perform(request: route, response: Response()) { (_, response) in
            if response.responseCode == APIErrorCode.responseOK {
                completion(.success(()))
            } else {
                if let error = response.error {
                    completion(.failure(SignupError.generic(message: error.localizedDescription, code: response.responseCode ?? 0, originalError: error)))
                } else {
                    completion(.failure(SignupError.unknown))
                }
            }
        }
    }

    public func validatePhoneNumberServerSide(number: String, completion: @escaping (Result<Void, SignupError>) -> Void) {
        let route = UserAPI.Router.validatePhone(phoneNumber: number)
        apiService.perform(request: route, response: Response()) { (_, response) in
            if response.responseCode == APIErrorCode.responseOK {
                completion(.success(()))
            } else {
                if let error = response.error {
                    completion(.failure(SignupError.generic(message: error.localizedDescription, code: response.responseCode ?? 0, originalError: error)))
                } else {
                    completion(.failure(SignupError.unknown))
                }
            }
        }
    }

    // MARK: Private interface

    private func getRandomSRPModulus(completion: @escaping (Result<AuthService.ModulusEndpointResponse, SignupError>) -> Void) {
        PMLog.debug("Getting random modulus")
        authenticator.getRandomSRPModulus { result in
            switch result {
            case .success(let res):
                completion(.success(res))
            case .failure(let error):
                completion(.failure(SignupError.generic(
                    message: error.userFacingMessageInNetworking,
                    code: error.codeInNetworking,
                    originalError: error
                )))
            }
        }
    }

    private struct AuthParameters {
        let salt: Data
        let verifier: Data
        let challenge: [[String: Any]]
        let productPrefix: String
    }

    private func generateAuthParameters(password: String, modulus: String) throws -> AuthParameters {
        guard let salt = try SrpRandomBits(PasswordSaltSize.login.IntBits) else {
            throw SignupError.randomBits
        }
        guard let auth = try SrpAuthForVerifier(password, modulus, salt) else {
            throw SignupError.cantHashPassword
        }
        let verifier = try auth.generateVerifier(2048)
        let challenge = apiService.challengeParametersProvider.provideParametersForLoginAndSignup()
        return AuthParameters(salt: salt, verifier: verifier, challenge: challenge, productPrefix: clientApp.name)
    }

    private func createUser(userName: String, password: String, email: String?, phoneNumber: String?, modulus: AuthService.ModulusEndpointResponse, domain: String?, completion: @escaping (Result<(), SignupError>) -> Void) {
        do {
            let authParameters = try generateAuthParameters(password: password, modulus: modulus.modulus)
            let userParameters = UserParameters(userName: userName, email: email, phone: phoneNumber, modulusID: modulus.modulusID, salt: authParameters.salt.encodeBase64(), verifer: authParameters.verifier.encodeBase64(), challenge: authParameters.challenge, productPrefix: authParameters.productPrefix, domain: domain)

            PMLog.debug("Creating user with username: \(userParameters.userName)")
            authenticator.createUser(userParameters: userParameters) { result in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(SignupError.generic(
                        message: error.userFacingMessageInNetworking,
                        code: error.codeInNetworking,
                        originalError: error
                    )))
                }
            }
        } catch {
            if let signupError = error as? SignupError {
                completion(.failure(signupError))
            } else {
                completion(.failure(.generateVerifier(underlyingErrorDescription: error.messageForTheUser)))
            }
        }
    }

    private func createExternalUser(email: String, password: String, modulus: AuthService.ModulusEndpointResponse, verifyToken: String, tokenType: String, completion: @escaping (Result<(), SignupError>) -> Void) {

        do {
            let authParameters = try generateAuthParameters(password: password, modulus: modulus.modulus)

            let externalUserParameters = ExternalUserParameters(email: email, modulusID: modulus.modulusID, salt: authParameters.salt.encodeBase64(), verifer: authParameters.verifier.encodeBase64(), challenge: authParameters.challenge, verifyToken: verifyToken, tokenType: tokenType, productPrefix: authParameters.productPrefix)

            PMLog.debug("Creating external user with email: \(externalUserParameters.email)")
            authenticator.createExternalUser(externalUserParameters: externalUserParameters) { result in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(SignupError.generic(
                        message: error.userFacingMessageInNetworking,
                        code: error.codeInNetworking,
                        originalError: error
                    )))
                }
            }
        } catch {
            if let signupError = error as? SignupError {
                completion(.failure(signupError))
            } else {
                completion(.failure(.generateVerifier(underlyingErrorDescription: error.messageForTheUser)))
            }
        }
    }
}
