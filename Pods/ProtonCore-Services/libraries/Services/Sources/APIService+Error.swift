//
//  ProtonMailAPIService.swift
//  ProtonCore-Services  - Created on 5/22/20.
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
//

import ProtonCore_Networking
import ProtonCore_CoreTranslation

public let APIServiceErrorDomain = NSError.protonMailErrorDomain("APIService")

public class APIErrorCode {
    public static let responseOK = 1000

    public static let HTTP503 = 503
    public static let HTTP504 = 504
    public static let HTTP404 = 404

    public static let badParameter = 1
    public static let badPath = 2
    public static let unableToParseResponse = 3
    public static let badResponse = 4

    public struct AuthErrorCode {
        public static let credentialExpired = 10
        public static let credentialInvalid = 20
        public static let invalidGrant = 30
        public static let unableToParseToken = 40
        public static let localCacheBad = 50
        public static let networkIusse = -1004
        public static let unableToParseAuthInfo = 70
        public static let authServerSRPInValid = 80
        public static let authUnableToGenerateSRP = 90
        public static let authUnableToGeneratePwd = 100
        public static let authInValidKeySalt = 110

        public static let authCacheLocked = 665

        public static let Cache_PasswordEmpty = 0x10000001
    }

    public static let API_offline = 7001

    public struct UserErrorCode {
        public static let userNameExsit = 12011
        public static let currentWrong = 12021
        public static let newNotMatch = 12022
        public static let pwdUpdateFailed = 12023
        public static let pwdEmpty = 12024
    }

    public static let badAppVersion = 5003
    public static let badApiVersion = 5005
    public static let appVersionTooOldForExternalAccounts = 5098
    public static let appVersionNotSupportedForExternalAccounts = 5099
    public static let humanVerificationRequired = 9001
    public static let deviceVerificationRequired = 9002
    public static let invalidVerificationCode = 12087
    public static let tooManyVerificationCodes = 12214
    public static let tooManyFailedVerificationAttempts = 85131
    public static let humanVerificationAddressAlreadyTaken = 2001
    public static let tls = 3500
    
    public static let humanVerificationEditEmail = 9100 // internal error
    
    public static let potentiallyBlocked = 111_222_333 // internal error
}

public extension ResponseError {
    var isApiIsBlockedError: Bool {
        return bestShotAtReasonableErrorCode == APIErrorCode.potentiallyBlocked
    }
    
    var isAppVersionTooOldForExternalAccountsError: Bool {
        guard let responseCode = responseCode else { return false }
        return responseCode == APIErrorCode.appVersionTooOldForExternalAccounts
    }
    
    var isAppVersionNotSupportedForExternalAccountsError: Bool {
        guard let responseCode = responseCode else { return false }
        return responseCode == APIErrorCode.appVersionNotSupportedForExternalAccounts
    }
}

public extension AuthErrors {
    static func from(_ responseError: ResponseError) -> AuthErrors {
        if responseError.isApiIsBlockedError {
            return .apiMightBeBlocked(message: responseError.networkResponseMessageForTheUser, originalError: responseError)
        } else if responseError.isAppVersionTooOldForExternalAccountsError {
            return .externalAccountsNotSupported(message: responseError.networkResponseMessageForTheUser, title: CoreString._ls_external_accounts_update_required_popup_title, originalError: responseError)
        } else if responseError.isAppVersionNotSupportedForExternalAccountsError {
            return .externalAccountsNotSupported(message: responseError.networkResponseMessageForTheUser, title: CoreString._ls_external_accounts_address_required_popup_title, originalError: responseError)
        } else {
            return .networkingError(responseError)
        }
    }
}
// This need move to a common framwork
public extension NSError {
    class func protonMailError(_ code: Int, localizedDescription: String, localizedFailureReason: String? = nil, localizedRecoverySuggestion: String? = nil) -> NSError {
        return NSError(domain: protonMailErrorDomain(), code: code, localizedDescription: localizedDescription, localizedFailureReason: localizedFailureReason, localizedRecoverySuggestion: localizedRecoverySuggestion)
    }

    class func protonMailErrorDomain(_ subdomain: String? = nil) -> String {
        var domain = Bundle.main.bundleIdentifier ?? "ch.protonmail"

        if let subdomain = subdomain {
            domain += ".\(subdomain)"
        }
        return domain
    }

    func getCode() -> Int {
        var defaultCode: Int = code
        if defaultCode == Int.max {
            if let detail = self.userInfo["com.alamofire.serialization.response.error.response"] as? HTTPURLResponse {
                defaultCode = detail.statusCode
            }
        }
        return defaultCode
    }

    func isInternetError() -> Bool {
        var isInternetIssue = false
        if self.userInfo["com.alamofire.serialization.response.error.response"] as? HTTPURLResponse != nil {
        } else {
            //                        if(error?.code == -1001) {
            //                            // request timed out
            //                        }
            if self.code == -1009 || self.code == -1004 || self.code == -1001 { // internet issue
                isInternetIssue = true
            }
        }
        return isInternetIssue
    }
    
    class func apiServiceError(code: Int, localizedDescription: String, localizedFailureReason: String?, localizedRecoverySuggestion: String? = nil) -> NSError {
        return NSError(
            domain: "APIService",
            code: code,
            localizedDescription: localizedDescription,
            localizedFailureReason: localizedFailureReason,
            localizedRecoverySuggestion: localizedRecoverySuggestion)
    }

    class func badResponse() -> NSError {
        return apiServiceError(
            code: APIErrorCode.badResponse,
            localizedDescription: "Bad response",
            localizedFailureReason: "Bad response")
    }
}
