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
}

public protocol NetworkStateInteractor {
    var state: AnyPublisher<NetworkState, Never> { get }
    func execute()
    func cancel()
}

public final class ConnectedNetworkStateInteractor: NetworkStateInteractor {
    public let resource: NetworkStateResource

    public var state: AnyPublisher<NetworkState, Never> {
        resource.state
    }

    public init(resource: NetworkStateResource) {
        self.resource = resource
    }

    public func execute() {
        resource.execute()
    }

    public func cancel() {
        resource.cancel()
    }
}
