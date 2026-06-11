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
import PDCore

// Object that holds state of applock. It's the single source of truth to be used by lower levels of app.
// `isLocked` will be true if the main key is not present (wiped after locking).
protocol LockedStateControllerProtocol {
    var isLocked: AnyPublisher<Bool, Never> { get }
}

final class LockedStateController: LockedStateControllerProtocol {
    private let eventsTriggerController: EventsTriggerController
    private let refreshableStorageResource: RefreshableStorageResource
    private let subject: CurrentValueSubject<Bool, Never>
    private var cancellables = Set<AnyCancellable>()

    var isLocked: AnyPublisher<Bool, Never> {
        subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(
        eventsTriggerController: EventsTriggerController,
        refreshableStorageResource: RefreshableStorageResource,
        isLocked: @escaping () -> Bool,
        removedMainKeyPublisher: AnyPublisher<Void, Never>,
        obtainedMainKeyPublisher: AnyPublisher<Void, Never>
    ) {
        self.eventsTriggerController = eventsTriggerController
        self.refreshableStorageResource = refreshableStorageResource
        let isLocked = isLocked()
        subject = CurrentValueSubject(isLocked)
        subscribeToUpdates(removedMainKeyPublisher: removedMainKeyPublisher, obtainedMainKeyPublisher: obtainedMainKeyPublisher)
    }

    func subscribeToUpdates(
        removedMainKeyPublisher: AnyPublisher<Void, Never>,
        obtainedMainKeyPublisher: AnyPublisher<Void, Never>
    ) {
        removedMainKeyPublisher
            .sink { [weak self] in
                self?.handleLocked()
            }
            .store(in: &cancellables)

        obtainedMainKeyPublisher
            .sink { [weak self] in
                self?.handleObtainedMainKey()
            }
            .store(in: &cancellables)

        refreshableStorageResource.completion
            .sink { [weak self] in
                self?.subject.send(false)
            }
            .store(in: &cancellables)
    }

    private func handleLocked() {
        refreshableStorageResource.cancel()
        subject.send(true)
    }

    private func handleObtainedMainKey() {
        // In case some objects were read before main key was obtained, we need to clean memory state so they can be read (and decrypted) again
        // The correct solution would be to disable reading & writing to CD during locked state, but that's beyond possible
        // with the current codebase.
        // Once finished, the `refreshableStorageResource` should notify to allow us set the unlocked flag
        refreshableStorageResource.resetMemoryState()
        eventsTriggerController.forcePolling(volumeIDs: [])
    }
}
