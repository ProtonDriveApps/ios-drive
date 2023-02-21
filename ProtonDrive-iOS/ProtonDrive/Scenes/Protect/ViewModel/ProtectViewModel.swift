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
import PDCore

final class ProtectViewModel: LogoutRequesting {
    private var cancellables = Set<AnyCancellable>()

    let isLockedPublisher: AnyPublisher<Bool, Never>

    init(
        lockManager: LockManager,
        signoutManager: SignOutManager,
        isLocked: @escaping () -> Bool,
        removedMainKeyPublisher: AnyPublisher<Void, Never>,
        obtainedMainKeyPublisher: AnyPublisher<Void, Never>
    ) {
        let initialStatus = isLocked()
        let subject: CurrentValueSubject<Bool, Never> = .init(initialStatus)

        removedMainKeyPublisher
            .sink { subject.send(true) }
            .store(in: &cancellables)

        obtainedMainKeyPublisher
            .sink { subject.send(false) }
            .store(in: &cancellables)

        isLockedPublisher = subject
            .removeDuplicates()
            .eraseToAnyPublisher()

        isLockedPublisher
            .sink { isLocked in
                isLocked ? lockManager.onLock() : lockManager.onUnlock()
            }
            .store(in: &cancellables)

        DriveNotification.signOut.publisher
            .sink { _ in
                signoutManager.signOut()
                ConsoleLogger.shared?.log(DriveError(DriveLogout(), "ProtectViewModel", method: "DriveNotification.signOut"))
                NotificationCenter.default.post(.checkAuthentication)
            }
            .store(in: &cancellables)
    }
}

struct DriveLogout: Error { }
