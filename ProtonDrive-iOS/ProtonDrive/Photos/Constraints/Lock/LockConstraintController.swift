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
import PDCore

final class LockConstraintController: PhotoBackupConstraintController {
    private let isLockedSubject: CurrentValueSubject<Bool, Never>
    private var cancellables = Set<AnyCancellable>()

    init(
        isLockedResource: @escaping () -> Bool,
        removedMainKeyResource: AnyPublisher<Void, Never>,
        obtainedMainKeyResource: AnyPublisher<Void, Never>
    ) {
        let initialStatus = isLockedResource()
        let subject = CurrentValueSubject<Bool, Never>(initialStatus)
        self.isLockedSubject = subject

        removedMainKeyResource
            .sink { subject.send(true) }
            .store(in: &cancellables)

        obtainedMainKeyResource
            .sink { subject.send(false) }
            .store(in: &cancellables)
    }

    var constraint: AnyPublisher<Bool, Never> {
        isLockedSubject
            .removeDuplicates()
            .handleEvents(receiveOutput: {
                Log.info("LockConstraintController.isLockedSubject 🔐: \($0)", domain: .application)
            })
            .eraseToAnyPublisher()
    }
}
