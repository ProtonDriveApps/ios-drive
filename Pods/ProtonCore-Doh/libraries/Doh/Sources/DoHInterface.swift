//
//  DoHInterface.swift
//  ProtonCore-Doh - Created on 2/24/20.
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
import ProtonCoreLog
import ProtonCoreUtilities

struct RuntimeError: Error {
    let message: String
    init(_ message: String) {
        self.message = message
    }
    public var localizedDescription: String {
        return message
    }
}

struct DNSCache {
    let dns: DNS
    let fetchTime: Double
}

public enum DoHStatus {
    case on
    case off
    case forceAlternativeRouting
    @available(*, deprecated, renamed: "on")
    case auto // mix don't know yet
}

public enum APNEnvironment: Int {
    case production = 6
    case development = 16
}

/// server configuration
public protocol ServerConfig {

    /// enable doh or not default is True. if you don't want to use doh, set this value to false
    var enableDoh: Bool { get }

    /// default host -- proton mail server url
    var defaultHost: String { get }

    /// default host path -- server url path for example: /api
    var defaultPath: String { get }

    /// captcha response host
    var captchaHost: String { get }
    var humanVerificationV3Host: String { get }

    // account host
    var accountHost: String { get }

    // default signup domain for this server url
    var signupDomain: String { get }

    /// debug mode vars
    var debugMode: Bool { get }
    var blockList: [String: Int] { get }

    /// the doh provider timeout  the default value is 5s
    var timeout: TimeInterval { get }
    var proxyToken: String? { get }

    /// the APNS Environment to use
    var apnEnvironment: APNEnvironment { get }
}

public extension ServerConfig {
    var defaultPath: String {
        return ""
    }

    var debugMode: Bool {
        return false
    }

    var blockList: [String: Int] {
        return [String: Int]()
    }

    var enableDoh: Bool {
        return true
    }

    var timeout: TimeInterval {
        return 20
    }

    var apnEnvironment: APNEnvironment {
        .development
    }
}

extension DoH {
    public struct PinningConfigurationEntry {
        static let catchAllHost = "*"

        let allowSubdomains: Bool
        let allowIPs: Bool

        public init(allowSubdomains: Bool, allowIPs: Bool) {
            self.allowIPs = allowIPs
            self.allowSubdomains = allowSubdomains
        }

        func allowsHost(_ host: String, for configuredHost: String) -> Bool {
            let host = host.lowercased()
            let configuredHost = configuredHost.lowercased().trimmingCharacters(in: .init(charactersIn: "."))

            if host == configuredHost {
                return true
            } else if allowSubdomains && host.hasSuffix(".\(configuredHost)") {
                return true
            } else if configuredHost == Self.catchAllHost && allowIPs && host.isIp {
                return true
            }
            return false
        }
    }

    internal static var pinningConfiguration: [String: PinningConfigurationEntry] = [:]

    public class func setPinningConfiguration(_ configuration: [String: PinningConfigurationEntry]) {
        pinningConfiguration = configuration
    }

    public class func hostIsPinned(_ host: String) -> Bool {
        for (pinnedHost, entry) in pinningConfiguration {
            if entry.allowsHost(host, for: pinnedHost) {
                return true
            }
        }
        return false
    }
}

public extension ServerConfig {
    @available(*, deprecated, message: "No longer needed not used, can be deleted")
    var apiHost: String { "" }
}

@available(*, deprecated, message: "Please use CompletionBlockExecutor from ProtonCore-Utilities")
public protocol DoHWorkExecutor {
    func execute(work: @escaping () -> Void)
}

@available(*, deprecated, message: "Please use CompletionBlockExecutor from ProtonCore-Utilities")
extension DispatchQueue: DoHWorkExecutor {
    public func execute(work: @escaping () -> Void) {
        self.async { work() }
    }
}

public protocol DoHInterface {

    func clearCache()

    func getProxyToken() -> String?
    func getCurrentlyUsedHostUrl() -> String
    func getCaptchaHostUrl() -> String
    func getHumanVerificationV3Host() -> String
    func getAccountHost() -> String
    func getAccountHostForAPI() -> String
    func getAPNEnvironment() -> APNEnvironment

    func getCurrentlyUsedUrlHeaders() -> [String: String]
    func getCaptchaHeaders() -> [String: String]
    func getHumanVerificationV3Headers() -> [String: String]
    func getAccountHeaders() -> [String: String]

    func errorIndicatesDoHSolvableProblem(error: Error?) -> Bool

    func getSignUpString() -> String
    var isCurrentlyUsingProxyDomain: Bool { get }
    var status: DoHStatus { get set }

    var currentlyUsedCookiesStorage: HTTPCookieStorage? { get }
    func setUpCookieSynchronization(storage: HTTPCookieStorage?)
    func synchronizeCookies(with response: URLResponse?, requestHeaders: [String: String]) async

    func handleErrorResolvingProxyDomainIfNeeded(
        host: String, requestHeaders: [String: String], sessionId: String?, error: Error?,
        callCompletionBlockUsing: CompletionBlockExecutor, completion: @escaping (Bool) -> Void
    )

    func handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(
        host: String, requestHeaders: [String: String], sessionId: String?, response: URLResponse?, error: Error?,
        callCompletionBlockUsing: CompletionBlockExecutor, completion: @escaping (Bool) -> Void
    )

    // MARK: - Deprecated API

    @available(*, deprecated, renamed: "clearCache")
    func clearAll()

    @available(*, deprecated, message: "Please use errorIndicatesDoHSolvableProblem(error:) instead")
    func codeCheck(code: Int) -> Bool

    @available(*, deprecated, message: "Please use getCurrentlyUsedHostUrl() in places you want to synchronously get the host url. Use handleErrorResolvingProxyDomainIfNeeded(host:error:completion:) in places that you handle the errors that should result in switching to proxy domain")
    func getHostUrl() -> String

    @available(*, deprecated, message: "Please use handleErrorResolvingProxyDomainIfNeeded(host:error:callCompletionBlockOn:completion:)")
    func handleError(host: String, error: Error?) -> Bool
}

public extension DoHInterface {

    @available(*, deprecated, message: "Please use handleErrorResolvingProxyDomainIfNeeded(host:requestHeaders:sessionId:error:callCompletionBlockUsing:completion:)")
    func handleErrorResolvingProxyDomainIfNeeded(host: String, sessionId: String?, error: Error?,
                                                 completion: @escaping (Bool) -> Void) {
        handleErrorResolvingProxyDomainIfNeeded(host: host, requestHeaders: [:], sessionId: sessionId, error: error,
                                                callCompletionBlockUsing: .asyncMainExecutor, completion: completion)
    }

    @available(*, deprecated, message: "Please use variant taking CompletionBlockExecutor from ProtonCore-Utilities: handleErrorResolvingProxyDomainIfNeeded(host:requestHeaders:error:callCompletionBlockUsing:completion:)")
    func handleErrorResolvingProxyDomainIfNeeded(host: String, error: Error?,
                                                 callCompletionBlockOn: DoHWorkExecutor?, completion: @escaping (Bool) -> Void) {
        guard let callCompletionBlockOn = callCompletionBlockOn else {
            handleErrorResolvingProxyDomainIfNeeded(host: host, requestHeaders: [:], sessionId: nil, error: error,
                                                    callCompletionBlockUsing: .asyncMainExecutor, completion: completion)
            return
        }
        let executor = CompletionBlockExecutor { _, work in callCompletionBlockOn.execute(work: work) }
        handleErrorResolvingProxyDomainIfNeeded(host: host, requestHeaders: [:], sessionId: nil, error: error,
                                                callCompletionBlockUsing: executor, completion: completion)
    }

    @available(*, deprecated, message: "Please use handleErrorResolvingProxyDomainIfNeeded(host:requestHeaders:sessionId:error:callCompletionBlockUsing:completion:)")
    func handleErrorResolvingProxyDomainIfNeeded(host: String, error: Error?,
                                                 callCompletionBlockUsing: CompletionBlockExecutor, completion: @escaping (Bool) -> Void) {
        handleErrorResolvingProxyDomainIfNeeded(host: host, requestHeaders: [:], sessionId: nil, error: error,
                                                callCompletionBlockUsing: callCompletionBlockUsing, completion: completion)
    }

    @available(*, deprecated, message: "Please use handleErrorResolvingProxyDomainIfNeeded(host:requestHeaders:sessionId:error:callCompletionBlockUsing:completion:)")
    func handleErrorResolvingProxyDomainIfNeeded(host: String, sessionId: String?, error: Error?,
                                                 callCompletionBlockUsing: CompletionBlockExecutor, completion: @escaping (Bool) -> Void) {
        handleErrorResolvingProxyDomainIfNeeded(host: host, requestHeaders: [:], sessionId: sessionId, error: error,
                                                callCompletionBlockUsing: callCompletionBlockUsing, completion: completion)
    }

    @available(*, deprecated, message: "Please use handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host:requestHeaders:sessionId:response:error:callCompletionBlockUsing:completion:)")
    func handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host: String, sessionId: String?, response: URLResponse?, error: Error?,
                                                                        completion: @escaping (Bool) -> Void) {
        handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host: host, requestHeaders: [:], sessionId: sessionId, response: response,
                                                                       error: error, callCompletionBlockUsing: .asyncMainExecutor, completion: completion)
    }

    @available(*, deprecated, message: "Please use handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host:requestHeaders:sessionId:response:error:callCompletionBlockUsing:completion:)")
    func handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host: String, response: URLResponse?, error: Error?,
                                                                        callCompletionBlockUsing: CompletionBlockExecutor, completion: @escaping (Bool) -> Void) {
        handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host: host, requestHeaders: [:], sessionId: nil, response: response,
                                                                       error: error, callCompletionBlockUsing: .asyncMainExecutor, completion: completion)
    }

    @available(*, deprecated, message: "Please use handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host:requestHeaders:sessionId:response:error:callCompletionBlockUsing:completion:)")
    func handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host: String, sessionId: String?, response: URLResponse?, error: Error?,
                                                                        callCompletionBlockUsing: CompletionBlockExecutor, completion: @escaping (Bool) -> Void) {
        handleErrorResolvingProxyDomainAndSynchronizingCookiesIfNeeded(host: host, requestHeaders: [:], sessionId: sessionId, response: response,
                                                                       error: error, callCompletionBlockUsing: .asyncMainExecutor, completion: completion)
    }

    @available(*, deprecated, message: "Please use the async variant of this function instead.")
    func synchronizeCookies(with response: URLResponse?, requestHeaders: [String: String], completion: @escaping () -> Void) {
        Task {
            await synchronizeCookies(with: response, requestHeaders: requestHeaders)
            completion()
        }
    }
}

fileprivate extension String {
    var isIp: Bool {
        return withCString { cStringPtr in
            var addr = in6_addr()
            return inet_pton(AF_INET, cStringPtr, &addr) == 1 ||
                   inet_pton(AF_INET6, cStringPtr, &addr) == 1
        }
    }
}
