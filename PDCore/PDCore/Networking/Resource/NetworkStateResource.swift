// Copyright (c) 2023 Proton AG
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

public protocol NetworkStateResource {
    var state: AnyPublisher<NetworkState, Never> { get }
    func execute()
    func cancel()
}

public final class MonitoringNetworkStateResource: NetworkStateResource {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkStateResourceQueue")
    private let stateSubject = CurrentValueSubject<NetworkState, Never>(.reachable(.other))

    public var state: AnyPublisher<NetworkState, Never> {
        stateSubject
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main) // Let's try to avoid temporary glitches in connection.
            .eraseToAnyPublisher()
    }

    public init() {}

    public func execute() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handleUpdate(path)
        }
        monitor.start(queue: queue)
        self.monitor = monitor
        #if os(iOS)
        // the current path just after monitor creation is always a "none" path for mac
        handleUpdate(monitor.currentPath)
        #endif
    }

    public func cancel() {
        monitor?.cancel()
        monitor = nil
    }

    private func handleUpdate(_ path: NWPath) {
        guard path.status == .satisfied else {
            Log.info("\(Self.self) update: is unreachable", domain: .networking)
            stateSubject.send(.unreachable)
            return
        }

        #if os(macOS)
        Log.info("\(Self.self) update: is reachable", domain: .networking)
        stateSubject.send(.reachable(.other))
        #else

        logReachableUpdate(with: path)
        if path.usesInterfaceType(.cellular) {
            stateSubject.send(.reachable(.cellular))
        } else if path.usesInterfaceType(.wifi) {
            stateSubject.send(.reachable(.wifi))
        } else if path.usesInterfaceType(.wiredEthernet) {
            stateSubject.send(.reachable(.wired))
        } else if path.usesInterfaceType(.loopback) {
            stateSubject.send(.reachable(.loopback))
        } else {
            // Otherwise we don't know the state
            stateSubject.send(.unreachable)
        }
        #endif
    }

    private func logReachableUpdate(with path: NWPath) {
        let interfaces = path.availableInterfaces.map { makeInterfaceLog(path: path, interface: $0) }
        let interfacesString = interfaces.joined(separator: ", ")
        Log.info("\(Self.self) update: is reachable. Available interfaces: \(interfacesString)", domain: .networking)
    }

    private func makeInterfaceLog(path: NWPath, interface: NWInterface) -> String {
        let type = interface.type
        return "(\(type), is used: \(path.usesInterfaceType(type)))"
    }
}

#if DEBUG
public final class NetworkStateResourceMock: NetworkStateResource {
    private let stateSubject: CurrentValueSubject<NetworkState, Never>

    public var state: AnyPublisher<NetworkState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public init(mockedState: NetworkState) {
        stateSubject = .init(mockedState)
    }

    public func execute() {}

    public func cancel() {}
}
#endif
