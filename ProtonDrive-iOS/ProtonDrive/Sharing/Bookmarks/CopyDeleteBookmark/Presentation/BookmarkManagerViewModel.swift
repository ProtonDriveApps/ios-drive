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
import PDLocalization

protocol BookmarkManagerViewModelProtocol {
    func copyBookmarkUrl()
    func deleteBookmark()
}

final class BookmarkManagerViewModel: BookmarkManagerViewModelProtocol {
    private let urlConstructor: BookmarkUrlConstructorInteractorProtocol
    private let urlDelivery: BookmarkUrlDeliveryResourceProtocol
    private let messageHandler: UserMessageHandlerProtocol
    private let deleteUseCase: BookmarkDeleteUseCaseProtocol

    init(urlConstructor: BookmarkUrlConstructorInteractorProtocol, urlDelivery: BookmarkUrlDeliveryResourceProtocol, deleteUseCase: BookmarkDeleteUseCaseProtocol, messageHandler: UserMessageHandlerProtocol) {
        self.urlConstructor = urlConstructor
        self.urlDelivery = urlDelivery
        self.deleteUseCase = deleteUseCase
        self.messageHandler = messageHandler
    }

    func copyBookmarkUrl() {
        Task {
            do {
                let url = try await urlConstructor.makeURL()
                urlDelivery.deliver(url: url)
                messageHandler.handleSuccess(Localization.shared_with_me_bookmarks_copied)
            } catch {
                Log.error(error: error, domain: .sharing)
                messageHandler.handleError(PlainMessageError(Localization.shared_with_me_bookmarks_copy_url_error))
            }
        }
    }

    func deleteBookmark() {
        Task {
            do {
                try await deleteUseCase.delete()
            } catch {
                let plainError = PlainMessageError(error.localizedDescription)
                messageHandler.handleError(plainError)
            }
        }
    }
}
