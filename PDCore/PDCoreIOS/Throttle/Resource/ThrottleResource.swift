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

public protocol ThrottleResource {
    func throttle<R, E>(publisher: AnyPublisher<R, E>, milliseconds: Int) -> AnyPublisher<R, E>
}

public final class MainQueueThrottleResource: ThrottleResource {
    public init() {}

    public func throttle<R, E>(publisher: AnyPublisher<R, E>, milliseconds: Int) -> AnyPublisher<R, E> {
        publisher
            .throttle(for: .milliseconds(milliseconds), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
}
