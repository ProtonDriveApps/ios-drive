// Copyright (c) 2025 Proton AG
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
import PDCoreIOS

public final class PendingInvitationsStatusContainer {
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let tower: Tower
    private let configuration: PendingInvitationsConfiguration

    public init(tower: Tower, featureFlagsController: FeatureFlagsControllerProtocol, configuration: PendingInvitationsConfiguration) {
        self.featureFlagsController = featureFlagsController
        self.tower = tower
        self.configuration = configuration
    }

    // MARK: - PendingInvitationsStatus

    private func makePendingInvitationsStatusInteractor() -> PendingInvitationsStatusMonitorInteractorProtocol {
        let container = PendingInvitationsContainer(tower: tower, featureFlagsController: featureFlagsController, configuration: configuration)
        let interactor = container.makePendingInvitationsStatusInteractor()
        return MainQueueAdapter(instance: interactor)
    }

    func makePendingInvitationsStatusViewModel() -> PendingInvitationsStatusViewModel {
        let interactor = makePendingInvitationsStatusInteractor()
        return PendingInvitationsStatusViewModel(interactor: interactor, messsageHandler: UserMessageHandler())
    }
}
