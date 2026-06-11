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

#if DEBUG

import Foundation
import PDCore

/// Entry point for early registration of network simulation Darwin notification observers.
/// Call from `AppDelegate.didFinishLaunchingWithOptions` so observers exist before
/// the test process sends `goSlow()` / `goOffline()`.
public enum NetworkSimulation {
    public static func startObserving() {
        NetworkSimulationURLProtocol.startObservingDarwinNotifications()
    }
}

// CFNotificationCallback requires a free function, static methods and closures that
// capture context are rejected by the compiler.
private let darwinHandlerLock = NSLock()
private var darwinHandlerRegistry = [String: () -> Void]()

private func networkSimulationDarwinCallback(
    _ center: CFNotificationCenter?,
    _ observer: UnsafeMutableRawPointer?,
    _ cfName: CFNotificationName?,
    _ object: UnsafeRawPointer?,
    _ userInfo: CFDictionary?
) {
    guard let cfName else { return }
    let key = cfName.rawValue as String
    darwinHandlerLock.lock()
    let handler = darwinHandlerRegistry[key]
    darwinHandlerLock.unlock()
    handler?()
}

/// Intercepts HTTP traffic at the URLSession transport layer for test simulation.
///
/// Three modes:
/// - `.passthrough`: `canInit` returns false, zero overhead.
/// - `.offline`: Fails requests with `URLError(.notConnectedToInternet)`.
/// - `.throttled(bytesPerSecond:)`: Delivers response data in metered chunks via GCD timer.
///
/// Controlled via Darwin notifications from `NetworkSimulationControl` in the test process.
final class NetworkSimulationURLProtocol: URLProtocol {

    // MARK: - Mode

    enum Mode: Equatable {
        case passthrough
        case offline
        case throttled(bytesPerSecond: Int)
    }

    private static let modeLock = NSLock()
    private static var _mode: Mode = .passthrough

    static var mode: Mode {
        get { modeLock.lock(); defer { modeLock.unlock() }; return _mode }
        set { modeLock.lock(); _mode = newValue; modeLock.unlock() }
    }

    // MARK: - Request tagging (prevents re-intercept by inner session)

    private static let tagKey = "NetworkSimulationURLProtocol.tagged"

    // MARK: - URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool {
        let currentMode = mode
        guard currentMode != .passthrough else { return false }
        let tagged = URLProtocol.property(forKey: tagKey, in: request) != nil
        let url = request.url?.absoluteString.prefix(120) ?? "<nil>"
        Log.debug("[NetworkSim] canInit check — mode=\(currentMode), alreadyTagged=\(tagged), url=\(url)", domain: .networking)
        return !tagged
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let currentMode = Self.mode
        let url = request.url?.absoluteString.prefix(120) ?? "<nil>"
        Log.debug("[NetworkSim] intercepting request — mode=\(currentMode), url=\(url)", domain: .networking)

        switch currentMode {
        case .passthrough:
            forwardRequest()

        case .offline:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))

        case .throttled(let bytesPerSecond):
            startThrottledForward(bytesPerSecond: bytesPerSecond)
        }
    }

    override func stopLoading() {
        innerTask?.cancel()
        throttleTimer?.cancel()
        throttleTimer = nil
    }

    // MARK: - Forwarding (passthrough race / inner session)

    private var innerTask: URLSessionDataTask?
    private var throttleTimer: DispatchSourceTimer?

    /// Forwards the request via an inner session that won't re-intercept.
    private func forwardRequest() {
        let tagged = Self.taggedCopy(of: request)
        let session = Self.innerSession
        let task = session.dataTask(with: tagged) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data, !data.isEmpty {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        innerTask = task
        task.resume()
    }

    // MARK: - Throttled delivery

    private func startThrottledForward(bytesPerSecond: Int) {
        let tagged = Self.taggedCopy(of: request)
        let session = Self.innerSession

        // Fetch entire response first, then meter delivery.
        // Acceptable for test files (≤40MB).
        let task = session.dataTask(with: tagged) { [weak self] data, response, error in
            guard let self else {
                Log.debug("[NetworkSim] throttled forward deallocated before inner session callback", domain: .networking)
                return
            }

            if let error {
                Log.debug("[NetworkSim] throttled forward failed — \(error.localizedDescription)", domain: .networking)
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            let bytes = data?.count ?? 0
            Log.debug("[NetworkSim] throttling delivery of \(bytes) bytes at \(bytesPerSecond) B/s", domain: .networking)

            guard let response, let data, !data.isEmpty else {
                if let response {
                    self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                self.client?.urlProtocolDidFinishLoading(self)
                return
            }

            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.deliverThrottled(data: data, bytesPerSecond: bytesPerSecond)
        }
        innerTask = task
        task.resume()
    }

    private func deliverThrottled(data: Data, bytesPerSecond: Int) {
        let chunkSize = max(bytesPerSecond / 10, 1)
        let intervalMs = 100 // 100ms between chunks
        var offset = 0

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: .milliseconds(intervalMs))
        throttleTimer = timer

        timer.setEventHandler { [weak self] in
            guard let self else { return }

            // Mid-transfer mode switch to offline → cancel with error
            if Self.mode == .offline {
                self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                timer.cancel()
                return
            }

            let end = min(offset + chunkSize, data.count)
            let chunk = data[offset..<end]
            self.client?.urlProtocol(self, didLoad: chunk)
            offset = end

            if offset >= data.count {
                self.client?.urlProtocolDidFinishLoading(self)
                timer.cancel()
            }
        }

        timer.resume()
    }

    // MARK: - Inner session (no custom protocols → no recursion)

    private static let innerSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        return URLSession(configuration: config)
    }()

    private static func taggedCopy(of request: URLRequest) -> URLRequest {
        let mutable = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: tagKey, in: mutable)
        return mutable as URLRequest
    }

    // MARK: - Darwin notification listener

    private static var observingNotifications = false

    /// Starts listening for Darwin notifications to switch modes.
    /// Safe to call multiple times (idempotent). Must be called early in app lifecycle
    /// so notifications from the test process aren't missed.
    static func startObservingDarwinNotifications() {
        guard !observingNotifications else { return }
        observingNotifications = true
        Log.debug("[NetworkSim] registering Darwin notification observers for mode switching", domain: .networking)

        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return }

        let offlineName = "ch.protonmail.drive.debug.urlprotocol.offline" as CFString
        let onlineName = "ch.protonmail.drive.debug.urlprotocol.online" as CFString
        let throttledName = "ch.protonmail.drive.debug.urlprotocol.throttled" as CFString

        registerDarwinObserver(center: center, name: offlineName) {
            Log.debug("[NetworkSim] Darwin notification received — switching to offline mode", domain: .networking)
            mode = .offline
        }

        registerDarwinObserver(center: center, name: onlineName) {
            Log.debug("[NetworkSim] Darwin notification received — switching to passthrough mode", domain: .networking)
            mode = .passthrough
        }

        registerDarwinObserver(center: center, name: throttledName) {
            Log.debug("[NetworkSim] Darwin notification received — switching to throttled mode (500 KB/s)", domain: .networking)
            mode = .throttled(bytesPerSecond: 500_000) // ~4 Mbps
        }
    }

    private static func registerDarwinObserver(
        center: CFNotificationCenter,
        name: CFString,
        handler: @escaping () -> Void
    ) {
        darwinHandlerLock.lock()
        darwinHandlerRegistry[name as String] = handler
        darwinHandlerLock.unlock()

        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(NetworkSimulationURLProtocol.self as AnyObject).toOpaque(),
            networkSimulationDarwinCallback,
            name,
            nil,
            .coalesce
        )
    }
}

#endif
