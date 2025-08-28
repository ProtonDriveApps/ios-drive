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
import PDCore
import PDCoreIOS

protocol AlbumInvitationsControllerProtocol {
    var status: AnyPublisher<PendingInvitationStatus, Never> { get }
    func loadIfNeeded()
    func refresh()
    func markNeeded()
}

final class AlbumInvitationsController: AlbumInvitationsControllerProtocol {
    private let facade: AlbumInvitationsFacadeProtocol
    private let subject = CurrentValueSubject<PendingInvitationStatus?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()
    private var shouldLoad = true

    var status: AnyPublisher<PendingInvitationStatus, Never> {
        subject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    init(facade: AlbumInvitationsFacadeProtocol) {
        self.facade = facade
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        facade.result
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)
    }

    private func handle(_ result: AlbumInvitationsResult) {
        switch result {
        case let .success(status):
            subject.send(status)
            shouldLoad = false
        case let .failure(error):
            Log.error(error: error, domain: .albums)
        }
    }

    func loadIfNeeded() {
        guard shouldLoad else {
            return
        }
        refresh()
    }

    func refresh() {
        facade.execute(with: AlbumInvitationsInput())
    }

    func markNeeded() {
        shouldLoad = true
    }
}
