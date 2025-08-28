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

import Combine
import PDLocalization
import PDCoreIOS

struct AlbumInvitationsViewData {
    let text: String
}

protocol AlbumInvitationsViewModelProtocol: ObservableObject {
    var text: String? { get }
    func onAppear()
    func open()
}

final class AlbumInvitationsViewModel: AlbumInvitationsViewModelProtocol {
    private let controller: AlbumInvitationsControllerProtocol
    private let coordinator: AlbumGalleryCoordinatorProtocol
    @Published var text: String?

    init(controller: AlbumInvitationsControllerProtocol, coordinator: AlbumGalleryCoordinatorProtocol) {
        self.controller = controller
        self.coordinator = coordinator
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        controller.status
            .compactMap { [weak self] status in
                self?.makeText(with: status)
            }
            .assign(to: &$text)
    }

    private func makeText(with status: PendingInvitationStatus) -> String? {
        switch status {
        case .none:
            return nil
        case let .some(count):
            return Localization.albums_pending_invitations_specific_title(count: count)
        case .many:
            return Localization.albums_pending_invitations_many_title
        }
    }

    func onAppear() {
        controller.loadIfNeeded()
    }

    func open() {
        controller.markNeeded()
        coordinator.openInvitations()
    }
}
