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

import Foundation
import PDLocalization
import PDCore
import PDCoreIOS

final class DeleteComputerAlertViewModel {
    private let computer: ComputerIdentifier
    private let computerRemover: ComputerRemover
    private let messageHandler: UserMessageHandlerProtocol

    init(computer: ComputerIdentifier, computerRemover: ComputerRemover, messageHandler: UserMessageHandlerProtocol = UserMessageHandler()) {
        self.computer = computer
        self.computerRemover = computerRemover
        self.messageHandler = messageHandler
    }

    // MARK: - Localizables
    var removeComputerRemoveMessage: String { Localization.computers_remove_computer_remove_message }
    var removeComputerRemoveButton: String { Localization.computers_remove_computer_remove_button }
    var removeComputerCancelButton: String { Localization.computers_remove_computer_cancel_button }

    func removeComputer() {
        Task {
            do {
                try await computerRemover.delete(computer: computer)
            } catch {
                await displayError(error)
            }
        }
    }

    @MainActor
    private func displayError(_ error: Error) {
        messageHandler.handleError(PlainMessageError(error.localizedDescription))
    }
}
