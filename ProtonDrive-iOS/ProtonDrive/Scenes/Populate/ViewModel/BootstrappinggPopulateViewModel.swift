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

import PDCore

final class BootstrappinggPopulateViewModel: PopulateViewModelProtocol {
    private let bootstrapper: AppBootstrapper
    private let onboardingObserver: OnboardingObserverProtocol
    private let coordinator: PopulateCoordinatorProtocol
    private let populatedStateController: PopulatedStateControllerProtocol

    public init(
        bootstrapper: AppBootstrapper,
        coordinator: PopulateCoordinatorProtocol,
        onboardingObserver: OnboardingObserverProtocol,
        populatedStateController: PopulatedStateControllerProtocol
    ) {
        self.bootstrapper = bootstrapper
        self.coordinator = coordinator
        self.onboardingObserver = onboardingObserver
        self.populatedStateController = populatedStateController
    }

    func populate() async throws {
        try await bootstrapper.bootstrap()
        onboardingObserver.startToObserveIsOnboardedStatus()
        await finish()
    }

    @MainActor
    private func finish() async {
        populatedStateController.setState(.populated)
        coordinator.showPopulated()
        onboardingObserver.startToObserveIsOnboardedStatus()
    }
}
