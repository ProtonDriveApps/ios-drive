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

import Foundation
import PDCore

public protocol PendingInvitationListCellViewModelProtocol: ObservableObject, Identifiable {
    var state: PendingInvitationListCellViewState? { get }
    func accept() async
    func reject() async
}

public struct PendingInvitationListCellViewState {
    let inviter: String
    let title: String
    let subtitle: String
    let iconName: FileAssetName
}

final class PendingInvitationListCellViewModel: PendingInvitationListCellViewModelProtocol {
    @Published var state: PendingInvitationListCellViewState?
    private var isPerformingOperation = false
    private let userMessageHandler: UserMessageHandlerProtocol

    let id: String
    private let repository: PendingInvitationDetailsRepositoryProtocol

    init(invitationId: String, repository: PendingInvitationDetailsRepositoryProtocol, userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()) {
        self.id = invitationId
        self.repository = repository
        self.userMessageHandler = userMessageHandler

        Task { await loadCell(id: invitationId) }
    }

    @MainActor
    func loadCell(id: String) async {
        let invitation = await repository.getPendingInvitation(id)
        self.state = self.map(invitation)
    }

    func map(_ invitation: PendingInvitation) -> PendingInvitationListCellViewState {
        PendingInvitationListCellViewState(
            inviter: String(invitation.inviterEmail.first ?? Character("-")).capitalized,
            title: invitation.name,
            subtitle: "\(invitation.inviterEmail) • \(DateFormatter.sharedWithMe.string(from: invitation.invitationDate))",
            iconName: FileTypeAsset.shared.getAsset(invitation.mimeType)
        )
    }

    @MainActor
    func accept() async {
        guard !isPerformingOperation else { return }
        isPerformingOperation = true
        do {
            try await repository.acceptPendingInvitation(id)
        } catch {
            userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
        isPerformingOperation = false
    }

    @MainActor
    func reject() async {
        guard !isPerformingOperation else { return }
        isPerformingOperation = true
        do {
            try await repository.rejectPendingInvitation(id)
        } catch {
            userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
        isPerformingOperation = false
    }
}

extension DateFormatter {
    static let sharedWithMe = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter

    }()
}
