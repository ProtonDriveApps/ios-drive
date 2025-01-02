// Copyright (c) 2023 Proton AG
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
import Foundation
import PDCore
import PDLocalization

final class ShareLinkViewModel: ObservableObject {
    private let model: ShareLinkModel
    private let closeScreenSubject: AnyPublisher<Void, Never>
    private let saveChangesSubject: AnyPublisher<Void, Never>
    private let editingLinkSubject: AnyPublisher<EditableData, Never>
    private var isEditingSubject: CurrentValueSubject<Bool, Never>
    private let now: Date

    @Published var state: ViewState = .sharing
    @Published var shouldClose = false
    @Published var showNonCommitedChangesAlert = false
    @Published var attemptDeleteLink = true

    private var proposedEdition = EditableData(expiration: nil, password: "") {
        didSet { isEditingSubject.send(self.isEditionInProgress()) }
    }
    private var cancellables = Set<AnyCancellable>()

    init(
        model: ShareLinkModel,
        closeScreenSubject: AnyPublisher<Void, Never>,
        saveChangesSubject: AnyPublisher<Void, Never>,
        editingLinkSubject: AnyPublisher<EditableData, Never>,
        isEditingSubject: CurrentValueSubject<Bool, Never>,
        now: () -> Date = Date.init
    ) {
        self.model = model
        self.closeScreenSubject = closeScreenSubject
        self.saveChangesSubject = saveChangesSubject
        self.editingLinkSubject = editingLinkSubject
        self.isEditingSubject = isEditingSubject
        self.now = now()

        closeScreenSubject
            .sink { [weak self] in self?.attemptClose() }
            .store(in: &cancellables)

        saveChangesSubject
            .sink { [weak self] in self?.save() }
            .store(in: &cancellables)

        editingLinkSubject
            .removeDuplicates()
            .sink { [weak self] in
                self?.proposedEdition = $0
            }
            .store(in: &cancellables)

        model.sharedLinkPublisher
            .map { EditableData.init(expiration: $0.expirationDate, password: $0.customPassword) }
            .sink { [weak self] in self?.proposedEdition = $0 }
            .store(in: &cancellables)
    }

    func isEditionInProgress() -> Bool {
        guard !state.isLoading else { return false }

        let linkModel = model.linkModel
        let editable = EditableData(
            expiration: linkModel.expirationDate,
            password: linkModel.customPassword
        )
        guard proposedEdition.password.count <= maximumPasswordSize else { return false }
        guard editable != proposedEdition else { return false }

        return true
    }

    func save() {
        guard isEditingSubject.value else { return }

        let prevState = state
        state = .loading(Localization.share_link_updating_title)

        do {
            let updates = try calculateExpirationUpdates()
            model.updateSecureLink(values: updates) { [weak self] result in
                switch result {
                case .success:
                    self?.state = .sharing
                    NotificationCenter.default.post(name: .banner, object: BannerModel.success(Localization.share_link_settings_updated))
                    
                case .failure(let error):
                    self?.state = prevState
                    NotificationCenter.default.post(name: .banner, object: BannerModel.failure(error))
                }
            }
        } catch {
            self.state = prevState
            NotificationCenter.default.post(name: .banner, object: BannerModel.failure(error))
        }
    }

    func attemptClose() {
        if isEditingSubject.value {
            showNonCommitedChangesAlert = true
        } else {
            shouldClose = true
        }
    }

    func saveAndClose() {
        guard isEditingSubject.value else { return }

        state = .loading(Localization.share_link_updating_title)

        do {
            let updates = try calculateExpirationUpdates()
            model.updateSecureLink(values: updates) { [weak self] result in
                self?.shouldClose = true
                switch result {
                case .success:
                    NotificationCenter.default.post(name: .banner, object: BannerModel.success(Localization.share_link_settings_updated, delay: .delayed))

                case .failure(let error):
                    NotificationCenter.default.post(name: .banner, object: BannerModel.failure(error, delay: .delayed))
                }
            }
        } catch {
            self.shouldClose = true
            NotificationCenter.default.post(name: .banner, object: BannerModel.failure(error, delay: .delayed))
        }
    }

    private func calculateExpirationUpdates() throws -> UpdateShareURLDetails {
        let currentLink = model.linkModel

        let currentCustomExpirationDate = currentLink.expirationDate
        let duration: UpdateShareURLDetails.Duration
        switch proposedEdition.expiration {
        case (let expiration?) where expiration != currentCustomExpirationDate:
            let secondsUntilExpiration = now.distance(to: expiration)
            duration = .expiring(secondsUntilExpiration)

            guard secondsUntilExpiration > .zero else { throw TimeError(Localization.share_link_past_date_error) }
        case .none:
            duration = .nonExpiring
        default:
            duration = .unchanged
        }

        let currentCustomPassword = currentLink.customPassword
        let password: UpdateShareURLDetails.Password
        switch proposedEdition.password {
        case (let pass) where pass.isEmpty && !currentCustomPassword.isEmpty:
            password = .updated(currentLink.invariantPassword)
        case (let pass) where !pass.isEmpty && currentCustomPassword != pass:
            password = .updated(currentLink.invariantPassword + pass)
        default:
            password = .unchanged
        }

        return UpdateShareURLDetails(password: password, duration: duration, permission: .unchanged)
    }

    func close() {
        self.shouldClose = true
    }

    enum ViewState {
        case loading(String)
        case sharing

        var isLoading: Bool {
            guard case .loading = self else { return false }
            return true
        }
    }

    var maximumPasswordSize: Int { 50 }

    var closeAlertModel: AlertModel {
        AlertModel(
            title: Localization.share_link_unsaved_change_alert_title,
            primaryAction: Localization.share_link_save_changes,
            secondaryAction: Localization.share_link_drop_unsaved_change_action
        )
    }
    
    struct AlertModel {
        let title: String
        let primaryAction: String
        let secondaryAction: String
    }

    struct TimeError: LocalizedError {
        let message: String

        internal init(_ message: String) {
            self.message = message
        }

        var errorDescription: String? {
            message
        }
    }
}

struct SharingLinkViewState: Equatable {
    let detailSection: SharedLinkSection
    let actionsSection: LinkActionsSection
}

struct SharedLinkSection: Equatable {
    let title: String
    let link: String
    let formattedText: FormattedText

    struct FormattedText: Equatable {
        let regular: String
        let bold: String
    }
}

struct LinkActionsSection: Equatable, ExpressibleByArrayLiteral {
    let actions: [ActionType]

    init(_ actions: [LinkActionsSection.ActionType]) {
        self.actions = actions
    }

    init(arrayLiteral elements: ActionType...) {
        self.actions = elements
    }

    enum ActionType {
        case copyLink
        case copyPassword
        case share
        case delete
    }
}
