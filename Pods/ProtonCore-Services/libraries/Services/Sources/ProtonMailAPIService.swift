//
//  ProtonMailAPIService.swift
//  ProtonCore-Services - Created on 5/22/20.
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

import Foundation
import ProtonCore_Doh
import ProtonCore_Log
import ProtonCore_Foundations
import ProtonCore_Networking
import ProtonCore_Utilities
import ProtonCore_Environment

#if canImport(TrustKit)
import TrustKit
import SwiftUI
#endif

// MARK: - Public API types

public protocol TrustKitProvider {
    var noTrustKit: Bool { get }
    var trustKit: TrustKit? { get }
}

public protocol URLCacheInterface {
    func removeAllCachedResponses()
}

extension URLCache: URLCacheInterface {}

public enum PMAPIServiceTrustKitProviderWrapper: TrustKitProvider {
    case instance
    public var noTrustKit: Bool { PMAPIService.noTrustKit }
    public var trustKit: TrustKit? { PMAPIService.trustKit }
}

extension PMAPIService.APIResponseCompletion {
 
    func call<T>(task: URLSessionDataTask?, error: API.APIError)
    where Left == API.JSONCompletion, Right == (_ task: URLSessionDataTask?, _ result: Result<T, API.APIError>) -> Void, T: APIDecodableResponse {
        switch self {
        case .left(let jsonCompletion): jsonCompletion(task, .failure(error))
        case .right(let decodableCompletion): decodableCompletion(task, .failure(error))
        }
    }
    
    func call<T>(task: URLSessionDataTask?, response: Either<[String: Any], T>)
    where Left == API.JSONCompletion, Right == (_ task: URLSessionDataTask?, _ result: Result<T, API.APIError>) -> Void, T: APIDecodableResponse {
        switch (self, response) {
        case (.left(let jsonCompletion), .left(let jsonObject)): jsonCompletion(task, .success(jsonObject))
        case (.right(let decodableCompletion), .right(let decodableObject)): decodableCompletion(task, .success(decodableObject))
        default:
            assertionFailure("Passing wrong response here indicates a programmers error")
        }
    }
}

extension PMAPIService.ResponseFromSession {
    
    func possibleError<T>() -> SessionResponseError?
    where Left == Result<JSONDictionary, SessionResponseError>, Right == Result<T, SessionResponseError>, T: SessionDecodableResponse {
        switch self {
        case .left(.success), .right(.success): return nil
        case .left(.failure(let error)), .right(.failure(let error)): return error
        }
    }
}

extension ResponseError: APIResponse {
    
    public var code: Int? {
        get { responseCode }
        set { self = ResponseError(httpCode: httpCode, responseCode: newValue, userFacingMessage: userFacingMessage, underlyingError: underlyingError) }
    }
    
    public var error: String? {
        get { userFacingMessage }
        set { self = ResponseError(httpCode: httpCode, responseCode: responseCode, userFacingMessage: newValue, underlyingError: underlyingError) }
    }
    
    public var details: HumanVerificationDetails? {
        guard let sessionError = underlyingError as? SessionResponseError else { return nil }
        switch sessionError {
        case .responseBodyIsNotAJSONDictionary(let body?, _), .responseBodyIsNotADecodableObject(let body?, _):
            struct ResponseWithHumanVerificationDetails: Codable { var details: HumanVerificationDetails? }
            return try? JSONDecoder.decapitalisingFirstLetter.decode(ResponseWithHumanVerificationDetails.self, from: body).details
        case .configurationError, .networkingEngineError, .responseBodyIsNotAJSONDictionary(body: nil, _), .responseBodyIsNotADecodableObject(body: nil, _): return nil
        }
    }
}

extension Either: APIResponse where Left == JSONDictionary, Right == ResponseError {
    
    var responseDictionary: JSONDictionary { mapRight { $0.serialized }.value() }
    
    public var code: Int? {
        get { mapLeft { $0.code }.mapRight { $0.code }.value() }
        set { self = mapLeft { var tmp = $0; tmp.code = newValue; return tmp }.mapRight { var tmp = $0; tmp.code = newValue; return tmp } }
    }
    
    public var error: String? {
        get { mapLeft { $0.error }.mapRight { $0.error }.value() }
        set { self = mapLeft { var tmp = $0; tmp.error = newValue; return tmp }.mapRight { var tmp = $0; tmp.error = newValue; return tmp } }
    }
    
    public var details: HumanVerificationDetails? {
        mapLeft { $0.details }.mapRight { $0.details }.value()
    }
}

public class PMAPIService: APIService {
    
    typealias ResponseFromSession<T> = Either<Result<JSONDictionary, SessionResponseError>, Result<T, SessionResponseError>> where T: SessionDecodableResponse
    typealias ResponseInPMAPIService<T> = Either<Result<JSONDictionary, API.APIError>, Result<T, API.APIError>> where T: APIDecodableResponse
    typealias APIResponseCompletion<T> = Either<JSONCompletion, DecodableCompletion<T>> where T: APIDecodableResponse

    public weak var forceUpgradeDelegate: ForceUpgradeDelegate?
    
    public weak var humanDelegate: HumanVerifyDelegate?
    
    public weak var authDelegate: AuthDelegate?
    
    public weak var serviceDelegate: APIServiceDelegate?
    
    public static var noTrustKit: Bool = false
    public static var trustKit: TrustKit?
    
    /// the session ID. this can be changed
    public var sessionUID: String = ""
    
    @available(*, deprecated, message: "This will be changed to DoHInterface type")
    public var doh: DoH & ServerConfig

    var dohInterface: DoHInterface { doh }
    
    public var signUpDomain: String {
        return self.dohInterface.getSignUpString()
    }
    
    let jsonDecoder: JSONDecoder = .decapitalisingFirstLetter
    
    private(set) var session: Session
    
    private(set) var isHumanVerifyUIPresented: Atomic<Bool> = .init(false)
    private(set) var isForceUpgradeUIPresented: Atomic<Bool> = .init(false)
    
    let hvDispatchGroup = DispatchGroup()
    let fetchAuthCredentialsAsyncQueue = DispatchQueue(label: "ch.proton.api.credential_fetch_async", qos: .userInitiated)
    let fetchAuthCredentialsSyncSerialQueue = DispatchQueue(label: "ch.proton.api.credential_fetch_sync", qos: .userInitiated)
    let fetchAuthCredentialCompletionBlockBackgroundQueue = DispatchQueue(
        label: "ch.proton.api.refresh_completion", qos: .userInitiated, attributes: [.concurrent]
    )

    let challengeParametersProvider: ChallengeParametersProvider
    
    /// by default will create a non auth api service. after calling the auth function, it will set the session. then use the delation to fetch the auth data  for this session.
    @available(*, deprecated, message: "This will be removed, use createAPIService, or createAPIServiceWithoutSession methods instead.")
    public required init(doh: DoH & ServerConfig,
                         sessionUID: String = "",
                         sessionFactory: SessionFactoryInterface = SessionFactory.instance,
                         cacheToClear: URLCacheInterface = URLCache.shared,
                         trustKitProvider: TrustKitProvider = PMAPIServiceTrustKitProviderWrapper.instance,
                         challengeParametersProvider: ChallengeParametersProvider) {
        self.doh = doh
        self.sessionUID = sessionUID
        self.challengeParametersProvider = challengeParametersProvider
        cacheToClear.removeAllCachedResponses()
        
        let apiHostUrl = self.doh.getCurrentlyUsedHostUrl()
        self.session = sessionFactory.createSessionInstance(url: apiHostUrl)
        
        self.session.setChallenge(noTrustKit: trustKitProvider.noTrustKit, trustKit: trustKitProvider.trustKit)
        
        doh.setUpCookieSynchronization(storage: self.session.sessionConfiguration.httpCookieStorage)
    }
    
    @available(*, deprecated, message: "This will be removed, use createAPIService, or createAPIServiceWithoutSession methods instead.")
    public required convenience init(doh: DoHInterface,
                                     sessionUID: String = "",
                                     sessionFactory: SessionFactoryInterface = SessionFactory.instance,
                                     cacheToClear: URLCacheInterface = URLCache.shared,
                                     trustKitProvider: TrustKitProvider = PMAPIServiceTrustKitProviderWrapper.instance,
                                     challengeParametersProvider: ChallengeParametersProvider) {
        guard let dohI = doh as? (DoH & ServerConfig) else {
            fatalError("DoH doesn't conform to DoH & ServerConfig")
        }
        self.init(doh: dohI, sessionUID: sessionUID,
                  sessionFactory: sessionFactory, cacheToClear: cacheToClear,
                  trustKitProvider: trustKitProvider,
                  challengeParametersProvider: challengeParametersProvider)
    }

    @available(*, deprecated, message: "This will be removed, use createAPIService, or createAPIServiceWithoutSession methods instead.")
    public convenience init(environment: ProtonCore_Environment.Environment,
                            sessionUID: String = "",
                            sessionFactory: SessionFactoryInterface = SessionFactory.instance,
                            cacheToClear: URLCacheInterface = URLCache.shared,
                            trustKitProvider: TrustKitProvider = PMAPIServiceTrustKitProviderWrapper.instance,
                            challengeParametersProvider: ChallengeParametersProvider) {
        self.init(doh: environment.doh, sessionUID: sessionUID,
                  sessionFactory: sessionFactory, cacheToClear: cacheToClear,
                  trustKitProvider: trustKitProvider,
                  challengeParametersProvider: challengeParametersProvider)
    }
    
    /**
     `createAPIService` creates `PMAPIService` with `doh` and `sessionID`
     It should be used when user is loged in and there is a `sessionUID` in cached `Credentials`

     - Parameter doh: required doh parameter conforming to the `DoHInterface` to encrypt domain name
     - Parameter sessionUID: required sessionUID parameter taken from cached `Credentials`
     - Parameter sessionFactory: sessionFactory parameter conforming to the `SessionFactoryInterface`, Default parameter creates `SessionFactory` instance that uses `Alamofire` session and request
     - Parameter cacheToClear: cacheToClear parameter conforming to the `URLCacheInterface`. Default parameter creates `URLCache` shared instance
     - Parameter trustKitProvider: trustKitProvider parameter conforming to the `TrustKitProvider`. Default parameter creates `PMAPIServiceTrustKitProviderWrapper` instance which allows or not to use the TrustKit
     - Returns:`PMAPIService` instance
     */
    public static func createAPIService(doh: DoHInterface,
                                        sessionUID: String,
                                        sessionFactory: SessionFactoryInterface = SessionFactory.instance,
                                        cacheToClear: URLCacheInterface = URLCache.shared,
                                        trustKitProvider: TrustKitProvider = PMAPIServiceTrustKitProviderWrapper.instance,
                                        challengeParametersProvider: ChallengeParametersProvider) -> PMAPIService {
        .init(doh: doh,
              sessionUID: sessionUID,
              sessionFactory: sessionFactory,
              cacheToClear: cacheToClear,
              trustKitProvider: trustKitProvider,
              challengeParametersProvider: challengeParametersProvider)
    }

    /**
     `createAPIServiceWithoutSession` creates `PMAPIService` with `doh` and without `sessionID`
     It should be used when user has logged out or never logged in

     - Parameter doh: required doh parameter conforming to the `DoHInterface` to encrypt domain name
     - Parameter sessionFactory: sessionFactory parameter conforming to the `SessionFactoryInterface`, Default parameter creates `SessionFactory` instance that uses `Alamofire` session and request
     - Parameter cacheToClear: cacheToClear parameter conforming to the `URLCacheInterface`. Default parameter creates `URLCache` shared instance
     - Parameter trustKitProvider: trustKitProvider parameter conforming to the `TrustKitProvider`. Default parameter creates `PMAPIServiceTrustKitProviderWrapper` instance which allows or not to use the TrustKit
     - Returns:`PMAPIService` instance
     */
    public static func createAPIServiceWithoutSession(doh: DoHInterface,
                                                      sessionFactory: SessionFactoryInterface = SessionFactory.instance,
                                                      cacheToClear: URLCacheInterface = URLCache.shared,
                                                      trustKitProvider: TrustKitProvider = PMAPIServiceTrustKitProviderWrapper.instance,
                                                      challengeParametersProvider: ChallengeParametersProvider) -> PMAPIService {
        .init(doh: doh,
              sessionUID: "",
              sessionFactory: sessionFactory,
              cacheToClear: cacheToClear,
              trustKitProvider: trustKitProvider,
              challengeParametersProvider: challengeParametersProvider)
    }

    /**
     `createAPIService` creates `PMAPIService` with `environment` and `sessionID`
     It should be used when user is loged in and there is a `sessionUID` in cached `Credentials`

     - Parameter environment: required environment parameter which contains `doh` needed  to encrypt domain name
     - Parameter sessionUID: required sessionUID parameter taken from cached `Credentials`
     - Parameter sessionFactory: sessionFactory parameter conforming to the `SessionFactoryInterface`, Default parameter creates `SessionFactory` instance that uses `Alamofire` session and request
     - Parameter cacheToClear: cacheToClear parameter conforming to the `URLCacheInterface`. Default parameter creates `URLCache` shared instance
     - Parameter trustKitProvider: trustKitProvider parameter conforming to the `TrustKitProvider`. Default parameter creates `PMAPIServiceTrustKitProviderWrapper` instance which allows or not to use the TrustKit
     - Returns:`PMAPIService` instance
     */
    public static func createAPIService(environment: ProtonCore_Environment.Environment,
                                        sessionUID: String,
                                        sessionFactory: SessionFactoryInterface = SessionFactory.instance,
                                        cacheToClear: URLCacheInterface = URLCache.shared,
                                        trustKitProvider: TrustKitProvider = PMAPIServiceTrustKitProviderWrapper.instance,
                                        challengeParametersProvider: ChallengeParametersProvider) -> PMAPIService {
        .init(doh: environment.doh,
              sessionUID: sessionUID,
              sessionFactory: sessionFactory,
              cacheToClear: cacheToClear,
              trustKitProvider: trustKitProvider,
              challengeParametersProvider: challengeParametersProvider)
    }
    
    /**
     `createAPIServiceWithoutSession` creates `PMAPIService` with `environment` and without `sessionID`
     It should be used when user has logged out or never logged in

     - Parameter environment: required environment parameter which contains `doh` needed  to encrypt domain name
     - Parameter sessionFactory: sessionFactory parameter conforming to the `SessionFactoryInterface`, Default parameter creates `SessionFactory` instance that uses `Alamofire` session and request
     - Parameter cacheToClear: cacheToClear parameter conforming to the `URLCacheInterface`. Default parameter creates `URLCache` shared instance
     - Parameter trustKitProvider: trustKitProvider parameter conforming to the `TrustKitProvider`. Default parameter creates `PMAPIServiceTrustKitProviderWrapper` instance which allows or not to use the TrustKit
     - Returns:`PMAPIService` instance
     */
    public static func createAPIServiceWithoutSession(environment: ProtonCore_Environment.Environment,
                                                      sessionFactory: SessionFactoryInterface = SessionFactory.instance,
                                                      cacheToClear: URLCacheInterface = URLCache.shared,
                                                      trustKitProvider: TrustKitProvider = PMAPIServiceTrustKitProviderWrapper.instance,
                                                      challengeParametersProvider: ChallengeParametersProvider) -> PMAPIService {
        .init(doh: environment.doh,
              sessionUID: "",
              sessionFactory: sessionFactory,
              cacheToClear: cacheToClear,
              trustKitProvider: trustKitProvider,
              challengeParametersProvider: challengeParametersProvider)
    }
    
    public func getSession() -> Session? {
        return session
    }
    
    public func setSessionUID(uid: String) {
        self.sessionUID = uid
    }
    
    func transformJSONCompletion(_ jsonCompletion: @escaping JSONCompletion) -> JSONCompletion {
        
        { task, result in
            switch result {
            case .failure: jsonCompletion(task, result)
            case .success(let dict):
                if let httpResponse = task?.response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let error: NSError
                    if let responseCode = dict["Code"] as? Int {
                        error = NSError(
                            domain: ResponseErrorDomains.withResponseCode.rawValue,
                            code: responseCode,
                            localizedDescription: dict["Error"] as? String ?? ""
                        )
                    } else {
                        error = NSError(
                            domain: ResponseErrorDomains.withStatusCode.rawValue,
                            code: httpResponse.statusCode,
                            localizedDescription: dict["Error"] as? String ?? ""
                        )
                    }
                    jsonCompletion(task, .failure(error))
                } else {
                    jsonCompletion(task, .success(dict))
                }
            }
        }
    }
}
