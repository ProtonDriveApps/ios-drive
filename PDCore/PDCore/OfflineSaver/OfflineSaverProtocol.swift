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

#if os(iOS)

import Combine

public enum OfflineSaverState: Equatable {
    case progress(Double)
    case inactive

    public var value: Double? {
        switch self {
        case .progress(let value):
            return value
        case .inactive:
            return nil
        }
    }
}

public protocol OfflineSaverProtocol: AnyObject {
    var state: AnyPublisher<OfflineSaverState, Never> { get }
    func start()
    func cleanUp()
}

#endif
