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
    private let controller: LockedStateControllerProtocol
    private let lockManager: LockManager
    private let coordinator: ProtectCoordinatorProtocol
    private var cancellables = Set<AnyCancellable>()
    private var lockCancellable: AnyCancellable?

    init(
        controller: LockedStateControllerProtocol,
        lockManager: LockManager,
        signoutManager: SignOutManager,
        coordinator: ProtectCoordinatorProtocol
    ) {
        self.controller = controller
        self.lockManager = lockManager
        self.coordinator = coordinator
        subscribeToSignOut(signoutManager: signoutManager)
    }

    func viewDidLoad() {
        lockCancellable = controller.isLocked
            .sink { [weak self] isLocked in
                self?.handleLockChange(isLocked)
            }
    }

    func reset() {
        Log.info("ProtectVM reset", domain: .application)
        lockCancellable?.cancel()
        lockCancellable = nil
    }

    private func handleLockChange(_ isLocked: Bool) {
        if isLocked {
            lockManager.onLock()
            coordinator.onLocked()
        } else {
            coordinator.onUnlocked()
        }
    }

    private func subscribeToSignOut(signoutManager: SignOutManager) {
        DriveNotification.signOut.publisher
            .sink { _ in
                Task {
                    Log.info("DriveNotification.signOut", domain: .application)
                    NotificationCenter.default.post(.isLoggingOut)
                    await signoutManager.signOut()
                    NotificationCenter.default.post(.checkAuthentication)
                }
            }
            .store(in: &cancellables)
    }
}
