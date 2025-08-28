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

import PDLocalization
import PDCore

struct AlbumContentOperationMessenger: PhotosMoveOperationMessageHandlerProtocol {
    private let userMessageHandler: UserMessageHandlerProtocol

    init(userMessageHandler: UserMessageHandlerProtocol) {
        self.userMessageHandler = userMessageHandler
    }

    func showAddPhotosBanner(for result: AlbumContentOperationResult) {
        var messages: [String] = []
        if result.failure != 0 {
            let message = Localization.item_failed_to_add(num: result.failure)
            messages.append(message)
        }
        if result.duplication != 0 {
            let message = Localization.item_already_exist(num: result.duplication)
            messages.append(message)
        }
        if result.success != 0 {
            let message = Localization.item_add_to_album(num: result.success)
            messages.append(message)
        }
        if result.incomplete != 0 {
            let message = Localization.item_failed_incomplete(num: result.incomplete)
            messages.append(message)
        }
        if messages.isEmpty { return }
        let message = messages.joined(separator: ", ")
        if result.failure != 0 {
            userMessageHandler.handleError(PlainMessageError(message))
        } else if result.duplication != 0 {
            userMessageHandler.handleWarning(message)
        } else {
            userMessageHandler.handleSuccess(message)
        }
    }

    func showRemovePhotosBanner(for result: AlbumContentOperationResult) {
        var messages: [String] = []
        if result.failure != 0 {
            let message = Localization.item_failed_to_remove(num: result.failure)
            messages.append(message)
        }
        if result.success != 0 {
            let message = Localization.item_remove_from_album(num: result.success)
            messages.append(message)
        }
        if messages.isEmpty { return }
        let message = messages.joined(separator: ", ")
        if result.failure != 0 {
            userMessageHandler.handleError(PlainMessageError(message))
        } else {
            userMessageHandler.handleSuccess(message)
        }
    }
}
