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
import PDLocalization
import Network

public enum NetworkState: Equatable {
    case reachable(Interface)
    case unreachable

    public enum Interface: Equatable {
        case cellular
        case loopback
        case other
        case wifi
        case wired
    }

    public var isReachable: Bool {
        switch self {
        case .reachable:
            return true
        case .unreachable:
            return false
        }
    }
}

public enum NetworkStateError: Error, LocalizedError {
    case deviceIsOffline

    public var errorDescription: String? {
        switch self {
        case .deviceIsOffline:
            return Localization.disconnection_view_title
        }
    }
}

public protocol NetworkStateInteractor {
    var state: AnyPublisher<NetworkState, Never> { get }
    func startMonitoring()
    func cancel()
}

public final class ConnectedNetworkStateInteractor: NetworkStateInteractor {
    public let resource: ConnectionStateResource

    public var state: AnyPublisher<NetworkState, Never> {
        resource.state
    }

    public init(resource: ConnectionStateResource) {
        self.resource = resource
    }

    public func startMonitoring() {
        resource.startMonitoring()
    }

    public func cancel() {
        resource.cancel()
    }
}
