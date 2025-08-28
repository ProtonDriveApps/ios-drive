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

final class BookmarkOpeningController: BookmarkOpeningControllerProtocol {
    private let interactor: BookmarkUrlConstructorInteractorProtocol
    private let coordinator: BookmarkOpeningCoordinatorProtocol
    private let errorController: UserMessageHandlerProtocol

    init(interactor: BookmarkUrlConstructorInteractorProtocol, coordinator: BookmarkOpeningCoordinatorProtocol, errorController: UserMessageHandlerProtocol) {
        self.interactor = interactor
        self.coordinator = coordinator
        self.errorController = errorController
    }

    func open() async {
        do {
            let url = try await interactor.makeURL()
            await coordinator.open(url)
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        Log.error("Failed to open Bookmark url", error: error, domain: .sharing)
        errorController.handleError(PlainMessageError(error.localizedDescription))
    }
}
