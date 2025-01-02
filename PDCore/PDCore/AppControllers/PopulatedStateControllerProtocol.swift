// Copyright (c) 2024 Proton AG
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

// Object that holds population state of the user. Is the source of truth for start app flow.
// Just after sign in it will be `unpopulated` and become `populated` as soon as roots are fetched.
public protocol PopulatedStateControllerProtocol {
    var state: AnyPublisher<PopulatedState, Never> { get }
    func setState(_ state: PopulatedState)
}

public final class PopulatedStateController: PopulatedStateControllerProtocol {
    private let subject = CurrentValueSubject<PopulatedState, Never>(.unpopulated)

    public init() { }

    public var state: AnyPublisher<PopulatedState, Never> {
        subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public func setState(_ state: PopulatedState) {
        subject.send(state)
    }
}

public enum PopulatedState: Equatable {
    case populated
    case unpopulated
}
