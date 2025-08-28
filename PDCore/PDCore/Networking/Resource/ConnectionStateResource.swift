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

import Combine
import Foundation
import Network
import ProtonCoreDoh

public protocol ConnectionStateResource {
    var currentState: NetworkState { get }
    var state: AnyPublisher<NetworkState, Never> { get }

    func startMonitor()
}

/// Monitors the device's connection status.
/// If the device is currently using a Wi-Fi interface, utilizes the HostPingInteractor to verify connectivity.
/// If the device is offline, will recheck the NWPath using an exponential backoff strategy.
public final class MonitorConnectionStateResource: ConnectionStateResource {
    private let doh: DoHInterface
    private let hostPingInteractor: HostPingInteractorProtocol
    private let monitorQueue = DispatchQueue(label: "com.proton.drive.connectionstateresource")
    private let pathMonitor: NWPathMonitor
    private let stateSubject = CurrentValueSubject<NetworkState, Never>(.reachable(.other))
    private var timer: Timer?
    private var doubleCheckAttempt = 1
    public private(set) var currentState: NetworkState = .reachable(.other) {
        didSet {
            if currentState == .unreachable {
                doubleCheckConnectionStatus()
            } else {
                invalidateTimer()
            }
            stateSubject.send(currentState)
        }
    }
    public var state: AnyPublisher<NetworkState, Never> {
        stateSubject
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main) // Let's try to avoid temporary glitches in connection.
            .eraseToAnyPublisher()
    }

    public init(doh: DoHInterface, urlSession: URLSessionProtocol = URLSession.shared) {
        self.doh = doh
        self.hostPingInteractor = HostPingInteractor(urlSession: urlSession, doh: doh)
        self.pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
               await self?.handleUpdate(path)
            }
        }
    }

    public func startMonitor() {
        pathMonitor.start(queue: monitorQueue)
    }
}

// MARK: - Analyze connection status
extension MonitorConnectionStateResource {
    private func handleUpdate(_ path: NWPath) async {
        if await isReachable(path) {
            reportOnline(path)
        } else {
            reportOffline(path)
        }
    }

    private func isReachable(_ path: NWPath) async -> Bool {
        guard path.status == .satisfied else { return false }
        // `.others` usually represents a VPN connection.
        // If it's the only available connection, assume the device is offline.
        let expected: Set<NWInterface.InterfaceType> = [.cellular, .wifi, .wiredEthernet]
        let intersection = expected.intersection(Set(path.availableInterfaces.map(\.type)))
        if path.usesInterfaceType(.wifi) {
            // The Wi-Fi router may be disconnected or not connected to the internet.
            return await hostPingInteractor.execute()
        } else {
            return !intersection.isEmpty
        }
    }

    private func reportOffline(_ path: NWPath) {
        logUpdate(with: path, isReachable: false)
        currentState = .unreachable
    }

    private func reportOnline(_ path: NWPath) {
        logUpdate(with: path, isReachable: true)

        if path.usesInterfaceType(.cellular) {
            currentState = .reachable(.cellular)
        } else if path.usesInterfaceType(.wifi) {
            currentState = .reachable(.wifi)
        } else if path.usesInterfaceType(.wiredEthernet) {
            currentState = .reachable(.wired)
        } else {
            // Otherwise we don't know the state
            currentState = .unreachable
        }
    }

    private func logUpdate(with path: NWPath, isReachable: Bool) {
        let interfaces = path.availableInterfaces.map { makeInterfaceLog(path: path, interface: $0) }
        let interfacesString = interfaces.joined(separator: ", ")
        let messages = [
            "Connection state: \(isReachable ? "reachable" : "unreachable")",
            " available interfaces: \(interfacesString)",
            " doh: \(doh.status)",
            " hostURL: \(doh.getCurrentlyUsedHostUrl())",
            " possibly use VPN: \(path.usesInterfaceType(.other))",
            " is using proxy: \(isUsingProxy())"
        ]
        Log.info(messages.joined(separator: "\n"), domain: .networking)
    }

    private func makeInterfaceLog(path: NWPath, interface: NWInterface) -> String {
        let type = interface.type
        return "(\(type), is used: \(path.usesInterfaceType(type)))"
    }

    private func isUsingProxy() -> Bool {
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return false
        }

        if let httpEnable = proxySettings["HTTPEnable"] as? NSNumber,
           httpEnable.boolValue,
           let httpProxy = proxySettings["HTTPProxy"] as? String,
           !httpProxy.isEmpty {
            return true
        }

        if let httpsEnable = proxySettings["HTTPSEnable"] as? NSNumber,
           httpsEnable.boolValue,
           let httpsProxy = proxySettings["HTTPSProxy"] as? String,
           !httpsProxy.isEmpty {
            return true
        }

        return false
    }
}

// MARK: - Double check timer
extension MonitorConnectionStateResource {
    private func doubleCheckConnectionStatus() {
        DispatchQueue.main.async {
            let interval = ExponentialBackoffWithJitter.getDelay(attempt: self.doubleCheckAttempt)
            self.doubleCheckAttempt += 1
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: false,
                block: { [weak self] _ in
                    self?.monitorQueue.async { [weak self] in
                        let attempt = self?.doubleCheckAttempt ?? -1
                        Log.debug("The \(attempt)th time to check the device connection status", domain: .networking)
                        guard let path = self?.pathMonitor.currentPath else { return }
                        Task {
                            await self?.handleUpdate(path)
                        }
                    }
                }
            )
        }
    }

    private func invalidateTimer() {
        DispatchQueue.main.async {
            self.doubleCheckAttempt = 1
            self.timer?.invalidate()
            self.timer = nil
        }
    }
}
