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
import ProtonCoreDoh

public protocol HostPingInteractorProtocol {
    func execute() async -> Bool
}

public final class HostPingInteractor: HostPingInteractorProtocol {
    private let urlSession: URLSessionProtocol
    private let doh: DoHInterface
    private let timeout: TimeInterval = 3
    private static let tooManyRedirectionsError = -1_007

    public init(
        urlSession: URLSessionProtocol = URLSession.shared,
        doh: DoHInterface
    ) {
        self.urlSession = urlSession
        self.doh = doh
    }

    /// - Returns: Has connection
    public func execute() async -> Bool {
        let serverRequest = makeProtonServerRequest()
        if await doRequest(serverRequest) { return true }

        let statusPageRequest = makeProtonStatusPageRequest()
        if await doRequest(statusPageRequest) { return true }

        return false
    }

    /// - Returns: Has connection
    private func doRequest(_ request: URLRequest) async -> Bool {
        do {
            _ = try await urlSession.data(for: request, delegate: nil)
            return true
        } catch {
            if error.bestShotAtReasonableErrorCode == Self.tooManyRedirectionsError {
                return true
            }
            return false
        }
    }

    private func makeProtonServerRequest() -> URLRequest {
        let serverLink = "\(doh.getCurrentlyUsedHostUrl())/core/v4/tests/ping"
        let url = URL(string: serverLink)!
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "HEAD"
        return request
    }

    private func makeProtonStatusPageRequest() -> URLRequest {
        let statusPageURL = URL(string: "https://status.proton.me")!
        var request = URLRequest(url: statusPageURL, timeoutInterval: timeout)
        request.httpMethod = "HEAD"
        return request
    }
}

public protocol URLSessionProtocol {
    func data(
        for request: URLRequest,
        delegate: (any URLSessionTaskDelegate)?
    ) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol { }
