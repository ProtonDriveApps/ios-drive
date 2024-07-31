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

final class PopulateViewModel: LogoutRequesting {
    private let lockedStateController: LockedStateControllerProtocol
    private let populatedStateController: PopulatedStateControllerProtocol
    private let populator: DrivePopulator
    private let eventsStarter: EventsSystemStarter
    private let onboardingObserver: OnboardingObserverProtocol
    private let coordinator: PopulateCoordinatorProtocol
    private var cancellables = Set<AnyCancellable>()

    public init(
        lockedStateController: LockedStateControllerProtocol,
        populatedStateController: PopulatedStateControllerProtocol,
        populator: DrivePopulator,
        eventsStarter: EventsSystemStarter,
        onboardingObserver: OnboardingObserverProtocol,
        coordinator: PopulateCoordinatorProtocol
    ) {
        self.lockedStateController = lockedStateController
        self.populatedStateController = populatedStateController
        self.populator = populator
        self.eventsStarter = eventsStarter
        self.onboardingObserver = onboardingObserver
        self.coordinator = coordinator
    }

    func viewDidLoad() {
        // It's necessary to subscribe after the view is loaded.
        // Any updates can be triggered immediately for logged in user and for continuing we need existing view stack.
        populatedStateController.state
            .sink { [weak self] state in
                self?.handleState(state)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(populatedStateController.state, lockedStateController.isLocked)
            .map { populateState, isLocked in
                populateState.isPopulated && !isLocked
            }
            .removeDuplicates()
            .sink { [weak self] isReady in
                // To start events we need both populated state and unlocked app.
                // Populated state should be set as soon as shares are fetched.
                // Unlocked state should be set if the user doesn't use 'applock' or when they enter correct one.
                if isReady {
                    self?.eventsStarter.startEventsSystem()
                }
            }
            .store(in: &cancellables)
    }

    private func handleState(_ state: PopulatedState) {
        Log.info("Populated state is changed to \(state.description)", domain: .application)
        switch state {
        case let .populated(with: id):
            coordinator.showPopulated(root: id)
            onboardingObserver.startToObserveIsOnboardedStatus()
        case .unpopulated:
            populate()
        }
    }

    private func populate() {
        populator.populate { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.populatedStateController.setState(self.populator.state)
            case .failure:
                self.requestLogout()
            }
        }
    }
}
