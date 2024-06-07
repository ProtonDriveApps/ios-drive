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

public protocol BackgroundTaskStateController {
    var isRunning: AnyPublisher<Bool, Never> { get }
    func start()
    func stop()
}

final class ConcreteBackgroundTaskStateController: BackgroundTaskStateController {
    private var subject = CurrentValueSubject<Bool, Never>(false)

    var isRunning: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        subject.send(true)
    }

    func stop() {
        subject.send(false)
    }
}
