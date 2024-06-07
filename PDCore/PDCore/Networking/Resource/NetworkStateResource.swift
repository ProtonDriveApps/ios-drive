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
        handleUpdate(monitor.currentPath)
    }

    public func cancel() {
        monitor?.cancel()
        monitor = nil
    }

    private func handleUpdate(_ path: NWPath) {
        guard path.status == .satisfied else {
            stateSubject.send(.unreachable)
            return
        }

        #if os(macOS)
        stateSubject.send(.reachable(.other))
        #else
        if path.usesInterfaceType(.cellular) {
            stateSubject.send(.reachable(.cellular))
        } else if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) || path.usesInterfaceType(.loopback) {
            stateSubject.send(.reachable(.other))
        } else {
            // Otherwise we don't know the state
            stateSubject.send(.unreachable)
        }
        #endif
    }
}
