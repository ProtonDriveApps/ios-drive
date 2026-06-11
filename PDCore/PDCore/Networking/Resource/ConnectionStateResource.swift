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

    func startMonitoring()
    func cancel()
}

/// Monitors the device's connection status.
/// If the device is currently using a Wi-Fi interface, utilizes the HostPingInteractor to verify connectivity.
/// If the device is offline, will recheck the NWPath using an exponential backoff strategy.
public final class MonitorConnectionStateResource: ConnectionStateResource {
    private let doh: DoHInterface
    private let hostPingInteractor: HostPingInteractorProtocol
    private let monitorQueue = DispatchQueue(label: "com.proton.drive.connectionstateresource.monitor")
    private let pathMonitor: NWPathMonitor
    private let stateSubject = CurrentValueSubject<NetworkState, Never>(.reachable(.other))
    private var timer: Timer?
    private var doubleCheckAttempt = 1
    private let reportingQueue = DispatchQueue(label: "com.proton.drive.connectionstateresource.report")
    private var lastLog = ""

    #if DEBUG
    /// When set, overrides the real network state
    private var simulatedState: NetworkState?
    #endif

    public var currentState: NetworkState {
        reportingQueue.sync { _currentState }
    }

    private var _currentState: NetworkState = .reachable(.other) {
        didSet {
            if _currentState == .unreachable {
                doubleCheckConnectionStatus()
            } else {
                invalidateTimer()
            }
            publishCurrentState()
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
            Task {
               await self?.handleUpdate(path)
            }
        }
    }

    /// Internal init for testing — allows injecting a custom ping interactor.
    init(doh: DoHInterface, hostPingInteractor: HostPingInteractorProtocol) {
        self.doh = doh
        self.hostPingInteractor = hostPingInteractor
        self.pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task {
               await self?.handleUpdate(path)
            }
        }
    }

    public func startMonitoring() {
        pathMonitor.start(queue: monitorQueue)
    }

    public func cancel() {
        pathMonitor.cancel()
        invalidateTimer()
    }

    // MARK: - Simulation support

    private func publishCurrentState() {
        let state = _currentState
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            #if DEBUG
            self.stateSubject.send(self.simulatedState ?? state)
            #else
            self.stateSubject.send(state)
            #endif
        }
    }
}

// MARK: - Analyze connection status
extension MonitorConnectionStateResource {
    func handleUpdate(_ path: NWPath) async {
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
        if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) || path.usesInterfaceType(.cellular) {
            // The router may be not connected to the internet. Cellular might have data off at the network operator level.
            return await hostPingInteractor.execute()
        } else {
            return !intersection.isEmpty
        }
    }

    func reportOffline(_ path: NWPath) {
        reportingQueue.sync {
            logUpdate(with: path, isReachable: false)
            _currentState = .unreachable
        }
    }

    func reportOnline(_ path: NWPath) {
        reportingQueue.sync {
            logUpdate(with: path, isReachable: true)
            
            if path.usesInterfaceType(.cellular) {
                _currentState = .reachable(.cellular)
            } else if path.usesInterfaceType(.wifi) {
                _currentState = .reachable(.wifi)
            } else if path.usesInterfaceType(.wiredEthernet) {
                _currentState = .reachable(.wired)
            } else if path.usesInterfaceType(.other) {
                _currentState = .reachable(.other)
            } else if path.usesInterfaceType(.loopback) {
                _currentState = .reachable(.loopback)
            } else {
                // Otherwise we don't know the state, but we know it's reachable, so let's default to other
                _currentState = .reachable(.other)
            }
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
        let log = messages.joined(separator: "\n")
        if lastLog == log { return } // don't spam log file 
        lastLog = log
        Log.info(log, domain: .networking)
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
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            let interval = ExponentialBackoffWithJitter.getDelay(attempt: self.doubleCheckAttempt)
            self.doubleCheckAttempt += 1
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: false,
                block: { [weak self] _ in
                    self?.performCurrentPathCheck()
                }
            )
        }
    }

    private func performCurrentPathCheck() {
        monitorQueue.async { [weak self] in
            DispatchQueue.main.async {
                let attempt = self?.doubleCheckAttempt ?? -1
                Log.debug("The \(attempt)th time to check the device connection status", domain: .networking)
            }
            guard let path = self?.pathMonitor.currentPath else { return }
            Task {
                await self?.handleUpdate(path)
            }
        }
    }

    private func invalidateTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.doubleCheckAttempt = 1
            self.timer?.invalidate()
            self.timer = nil
        }
    }
}

#if DEBUG
// MARK: - Network Simulation via Darwin Notifications
public extension DarwinNotification.Name {
    static let simulateNetworkOffline = DarwinNotification.Name("ch.protonmail.drive.debug.network.offline")
    static let simulateNetworkOnline = DarwinNotification.Name("ch.protonmail.drive.debug.network.online")
}

extension MonitorConnectionStateResource {
    /// Sets the simulated network state directly.
    /// - Parameter state: The network state to simulate, or nil to use real network state.
    public func setSimulatedState(_ state: NetworkState?) {
        simulatedState = state
        publishCurrentState()
    }

    /// Starts observing Darwin notifications for network simulation (QA toggle + UI tests).
    public func startObservingSimulationCommands(notificationCenter: DarwinNotificationCenter = .shared) {
        notificationCenter.addObserver(self, for: .simulateNetworkOffline) { [weak self] _ in
            DispatchQueue.main.async {
                Log.info("Network simulation: going offline", domain: .networking)
                self?.setSimulatedState(.unreachable)
            }
        }

        notificationCenter.addObserver(self, for: .simulateNetworkOnline) { [weak self] _ in
            DispatchQueue.main.async {
                Log.info("Network simulation: going online", domain: .networking)
                self?.setSimulatedState(nil)
            }
        }
    }
}
#endif
