// Copyright (c) 2026 Proton AG
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
import PDCore
import ProtonCoreServices

protocol URLSessionProvider {
    var session: URLSession { get }
    var delegate: URLSessionTaskDelegate { get }
}

struct DefaultURLSessionProvider: URLSessionProvider {

    static let instance = DefaultURLSessionProvider()

    let session: URLSession
    let delegate: URLSessionTaskDelegate

    private init() {
        let sslPinningDelegate = SSLPinningDelegate(
            trustKit: PMAPIService.trustKit, noTrustKit: PMAPIService.noTrustKit
        ) { request in
            Log.error("TLS pinning failed for \(request?.url?.absoluteString ?? "unknown url"))",
                      domain: .networking)
        }

        let config = URLSessionConfiguration.ephemeral.withTimeoutDisabled

        #if DEBUG
        config.protocolClasses = [NetworkSimulationURLProtocol.self] + (config.protocolClasses ?? [])
        NetworkSimulationURLProtocol.startObservingDarwinNotifications()
        #endif

        let session = URLSession(
            configuration: config,
            delegate: sslPinningDelegate,
            delegateQueue: nil
        )
        self.session = session
        self.delegate = sslPinningDelegate
    }
}

extension URLSessionConfiguration {
    var withTimeoutDisabled: Self {
        // Set timeout to 7 days - the default value of `timeoutIntervalForResource`
        // 7 days × 24 hours × 3_600 seconds = 604_800 seconds
        self.timeoutIntervalForRequest = 604_800

        // Also reset this to back its default value, in case it has been meddled with elsewhere
        self.timeoutIntervalForResource = 604_800
        
        // the number of parallel connections is decided by SDK, so here we only make sure the limit is high enough to never limit SDK
        self.httpMaximumConnectionsPerHost = 256
        
        // remove caching 
        self.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlCache = nil

        return self
    }
}
