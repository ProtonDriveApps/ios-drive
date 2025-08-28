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
import Combine
import PDCore
import PDLocalization

public protocol PendingInvitationListScreenViewModelProtocol: ObservableObject {
    var items: [String] { get }
    var isAscending: Bool { get }
    var title: String { get }
    var isFirstLoad: Bool { get }
    var emptyInvitationPublisher: AnyPublisher<Void, Never> { get }

    func toggleSortingOrder()
    func refresh() async
    func onDisappear()
}

final class PendingInvitationListScreenViewModel: PendingInvitationListScreenViewModelProtocol {
    @Published var items: [String] = []
    @Published var title: String = ""
    @Published var isFirstLoad: Bool = true
    var emptyInvitationPublisher: AnyPublisher<Void, Never> {
        emptyInvitationSubject.eraseToAnyPublisher()
    }

    private var isLoading: Bool = false
    private var cancellables: Set<AnyCancellable> = []
    private let repository: PendingInvitationRepositoryProtocol
    private let messageHandler: UserMessageHandlerProtocol
    private let userPreferencesRepository: PendingInvitationSortPreferenceRepositoryProtocol
    private let configuration: PendingInvitationsConfiguration
    private let changeController: PendingInvitationsChangeControllerProtocol
    private let emptyInvitationSubject: PassthroughSubject<Void, Never> = .init()

    init(
        repository: PendingInvitationRepositoryProtocol,
        messageHandler: UserMessageHandlerProtocol,
        userPreferencesRepository: PendingInvitationSortPreferenceRepositoryProtocol,
        configuration: PendingInvitationsConfiguration,
        changeController: PendingInvitationsChangeControllerProtocol
    ) {
        self.repository = repository
        self.messageHandler = messageHandler
        self.userPreferencesRepository = userPreferencesRepository
        self.configuration = configuration
        self.changeController = changeController
        updateTitle()

        repository.getPendingInvitationsIds()
            .throttle(for: 2, scheduler: DispatchQueue.main, latest: true)
            .removeDuplicates()
            .sink { [weak self] in
                guard let self else { return }
                self.setItems($0)
            }
            .store(in: &cancellables)
    }

    var isAscending: Bool {
        userPreferencesRepository.invitationSortPreference.isAscending
    }

    func toggleSortingOrder() {
        let currentPreference = userPreferencesRepository.invitationSortPreference
        userPreferencesRepository.invitationSortPreference = currentPreference.toggle()
        self.items = items.reversed()
    }

    private func updateTitle() {
        switch configuration {
        case .default:
            title = "\(Localization.pending_invitation_screen_title) (\(items.count))"
        case .albums:
            title = Localization.album_invitations_screen_title
        }
    }

    private func setItems(_ items: [String]) {
        if isAscending {
            self.items = items.reversed()
        } else {
            self.items = items
        }
        if !items.isEmpty {
            isFirstLoad = false
        }
        updateTitle()
        if items.isEmpty, !isFirstLoad {
            emptyInvitationSubject.send(())
        }
    }

    @MainActor
    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        do {
            try await repository.fetchAllInvitations()
        } catch {
            Log.error(error: error, domain: .sharing)
            messageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
        isFirstLoad = false
        isLoading = false
    }

    func onDisappear() {
        changeController.setUpdated()
    }
}
