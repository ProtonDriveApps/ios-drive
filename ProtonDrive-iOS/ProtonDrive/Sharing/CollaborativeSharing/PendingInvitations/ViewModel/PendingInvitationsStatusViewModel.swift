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
import PDCoreIOS
import PDLocalization

final class PendingInvitationsStatusViewModel: ObservableObject {
    struct ViewState {
        let title: String
        let message: String
    }
    
    private let interactor: PendingInvitationsStatusMonitorInteractorProtocol
    private let messsageHandler: UserMessageHandlerProtocol

    @Published var viewState: ViewState?

    init(interactor: PendingInvitationsStatusMonitorInteractorProtocol, messsageHandler: UserMessageHandlerProtocol) {
        self.interactor = interactor
        self.messsageHandler = messsageHandler
        self.viewState = viewState
    }

    @MainActor
    func onViewDidAppear() async {
        do {
            let status = try await interactor.getPendingInvitationsStatus()

            switch status {
            case .none:
                viewState = nil
            case .some(let sharedCount):
                let message = sharedCount == 1 ? Localization.shared_with_me_pending_invitation_section_message_one : "\(sharedCount) " + Localization.shared_with_me_pending_invitation_section_message_some
                viewState = ViewState(title: title, message: message)
            case .many:
                let message = Localization.shared_with_me_pending_invitation_section_message_many
                viewState = ViewState(title: title, message: message)
            }

        } catch {
            messsageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
    }

    private var title: String {
        Localization.shared_with_me_pending_invitation_section
    }
}
