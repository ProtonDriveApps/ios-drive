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

final class PendingInvitationsStatusMonitorInteractor: PendingInvitationsStatusMonitorInteractorProtocol {
    private let repository: InvitationsIdentifiersRepositoryProtocol

    init(repository: InvitationsIdentifiersRepositoryProtocol) {
        self.repository = repository
    }

    func getPendingInvitationsStatus() async throws -> PendingInvitationStatus {
        let invitations = try await repository.getInvitations()

        switch invitations.count {
        case .zero:
            return .none
        case 0...10:
            return .some(invitations.count)
        default:
            return .many
        }
    }
}

/// Remove once the feature flag is fully rolled out
final class FeatureFlagsPendingInvitationsStatusMonitorDecorator: PendingInvitationsStatusMonitorInteractorProtocol {
    private let interactor: PendingInvitationsStatusMonitorInteractorProtocol
    private let controller: FeatureFlagsControllerProtocol

    init(interactor: PendingInvitationsStatusMonitorInteractorProtocol, controller: FeatureFlagsControllerProtocol) {
        self.interactor = interactor
        self.controller = controller
    }

    func getPendingInvitationsStatus() async throws -> PendingInvitationStatus {
        if controller.hasAcceptRejectInvitations {
            return try await interactor.getPendingInvitationsStatus()
        } else {
            return .none
        }
    }
}
