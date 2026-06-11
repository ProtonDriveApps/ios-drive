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

final class ForegroundTransitionController {
    private let applicationStateController: ApplicationStateController
    private let lockedStateController: LockedStateControllerProtocol
    private let populatedInteractors: [CommandInteractor]
    private let interactors: [CommandInteractor]
    private var cancellables = Set<AnyCancellable>()
    
    init(
        applicationStateController: ApplicationStateController,
        interactors: [CommandInteractor],
        populatedInteractors: [CommandInteractor],
        populatedStateController: PopulatedStateControllerProtocol,
        lockedStateController: LockedStateControllerProtocol
    ) {
        self.applicationStateController = applicationStateController
        self.populatedInteractors = populatedInteractors
        self.lockedStateController = lockedStateController
        self.interactors = interactors

        applicationStateController.state.sink { [weak self] state in
            self?.handle(state)
        }.store(in: &cancellables)

        // Combine both state publishers and filter for foreground and populated conditions
        Publishers.CombineLatest3(applicationStateController.state, populatedStateController.state, lockedStateController.isLocked)
            .filter { appState, populatedState, isLocked in
                appState == .foreground && populatedState == .populated && !isLocked
            }
            .sink { [weak self] _ in
                self?.handleExclusivelyPopulated()
            }
            .store(in: &cancellables)
    }
    
    private func handle(_ state: ApplicationRunningState) {
        guard state == .foreground else {
            return
        }

        interactors.forEach { $0.execute() }
    }

    private func handleExclusivelyPopulated() {
        populatedInteractors.forEach { $0.execute() }
    }
}
