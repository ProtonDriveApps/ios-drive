// Copyright (c) 2025 Proton AG
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
import TrustKit
import ProtonCoreNetworking

public final class SSLPinningDelegate: NSObject, URLSessionTaskDelegate {
    
    private let trustKit: () -> TrustKit?
    private let noTrustKit: () -> Bool
    private let failedTLS: (URLRequest?) -> Void
    
    init(trustKit: @autoclosure @escaping () -> TrustKit?,
         noTrustKit: @autoclosure @escaping () -> Bool,
         failedTLS: @escaping (URLRequest?) -> Void) {
        self.trustKit = trustKit
        self.noTrustKit = noTrustKit
        self.failedTLS = failedTLS
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(nil, challenge, completionHandler)
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleChallenge(task, challenge, completionHandler)
    }

    private func handleChallenge(
        _ task: URLSessionTask?,
        _ challenge: URLAuthenticationChallenge,
        _ completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        handleAuthenticationChallenge(
            didReceive: challenge,
            noTrustKit: noTrustKit(),
            trustKit: trustKit(),
            challengeCompletionHandler: completionHandler
        ) { disposition, credential, completionHandler in
            if disposition == .cancelAuthenticationChallenge {
                self.failedTLS(task?.originalRequest)
            }
            completionHandler(disposition, credential)
        }
    }

}
