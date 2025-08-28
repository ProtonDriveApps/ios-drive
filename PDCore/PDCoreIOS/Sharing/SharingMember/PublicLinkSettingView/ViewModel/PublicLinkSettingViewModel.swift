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

import Combine
import Foundation
import PDCore
import PDLocalization

final class PublicLinkSettingViewModel: ObservableObject {
    @Published var enableExpirationDate: Bool
    @Published var enablePassword: Bool
    @Published var expirationDate: Date
    @Published var password: String
    @Published var isSaving = false
    let copyLinkButtonTitle = Localization.share_action_copy_link
    let copyPasswordButtonTitle = Localization.share_action_copy_password
    let datePickerPlaceholder = Localization.edit_link_placeholder_date_picker
    let dateRange: ClosedRange<Date>
    let expirationDateTitle = Localization.edit_link_title_expiration_date
    let legacyLinkWarning = Localization.share_legacy_link_warning
    let maximumPassword = 50
    let passwordPlaceholder = Localization.edit_link_placeholder_password
    let passwordTitle = Localization.edit_link_title_password
    let saveButtonTitle = Localization.general_save
    let sectionHeader = Localization.share_section_link_options
    let shareButtonTitle = Localization.share_action_share
    private let dependencies: Dependencies
    private let now: Date
    private var cancellables = Set<AnyCancellable>()
    private var initialData: DataStorage?
    private var hasChange = false
    private(set) var sharedLink: SharedLink
    private(set) var passwordHasChanged = false
    private(set) var expirationHasChanged = false
    
    init(
        dependencies: Dependencies,
        sharedLink: SharedLink,
        nowProvider: DateResource = PlatformCurrentDateResource()
    ) {
        self.dependencies = dependencies
        self.sharedLink = sharedLink
        password = sharedLink.customPassword
        enablePassword = !sharedLink.customPassword.isEmpty
        
        now = nowProvider.getDate()
        let lastExpirationDay = now.addingTimeInterval(90 * 24 * 3600) // 90 days
        let tomorrow = now.addingTimeInterval(24 * 3600)
        if let expiration = sharedLink.expirationDate {
            enableExpirationDate = true
            if expiration < now {
                self.dateRange = expiration...lastExpirationDay
                expirationDate = expiration
            } else {
                self.dateRange = tomorrow...lastExpirationDay
                expirationDate = expiration
            }
        } else {
            enableExpirationDate = false
            self.dateRange = tomorrow...lastExpirationDay
            expirationDate = lastExpirationDay
        }
        self.initialData = .init(
            enablePassword: enablePassword,
            password: password,
            enableExpiration: enableExpirationDate,
            expirationDate: expirationDate
        )
        subscribeForUpdate()
    }
    
    var enableSaveButton: Bool {
        hasChange && password.count <= maximumPassword
    }

    func saveChange() {
        isSaving = true
        do {
            guard let detail = try calculateExpirationUpdates() else { return }
            Task {
                do {
                    try await dependencies.sharedLinkRepository.updatePublicLink(
                        sharedLink.publicLinkIdentifier,
                        with: detail
                    )
                    await MainActor.run {
                        dependencies.coordinator.popViewController()
                        isSaving = false
                        dependencies.messageHandler.handleSuccess(Localization.edit_link_settings_updated)
                    }
                } catch {
                    dependencies.messageHandler.handleError(PlainMessageError(error.localizedDescription))
                    await MainActor.run {
                        isSaving = false
                    }
                }
            }
        } catch {
            isSaving = false
            dependencies.messageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
    }
    
    private func calculateExpirationUpdates() throws -> UpdateShareURLDetails? {
        guard let initialData else { return nil }
        let latestSetting = DataStorage(
            enablePassword: enablePassword,
            password: password,
            enableExpiration: enableExpirationDate,
            expirationDate: expirationDate
        )
        
        let duration: UpdateShareURLDetails.Duration
        let isExpirationChange = initialData.isExpirationChanged(from: latestSetting)

        switch (enableExpirationDate, isExpirationChange) {
        case (true, true):
            let secondsUntilExpiration = now.distance(to: expirationDate)
            duration = .expiring(secondsUntilExpiration)

            guard secondsUntilExpiration > .zero else { throw TimeError(Localization.share_link_past_date_error) }
        case (false, _):
            duration = .nonExpiring
        default:
            duration = .unchanged
        }

        let currentCustomPassword = sharedLink.customPassword
        let password: UpdateShareURLDetails.Password
        let isPasswordChanged = initialData.isPasswordChanged(from: latestSetting)

        switch isPasswordChanged {
        case true where self.password.isEmpty && !currentCustomPassword.isEmpty:
            password = .updated(sharedLink.invariantPassword)
        case true where !self.password.isEmpty && currentCustomPassword != self.password:
            password = .updated(sharedLink.invariantPassword + self.password)
        default:
            password = .unchanged
        }
        
        return UpdateShareURLDetails(password: password, duration: duration, permission: .unchanged)
    }
    
    private func subscribeForUpdate() {
        $enablePassword
            .dropFirst()
            .sink { [weak self] newValue in
                self?.checkData(observedEnablePassword: newValue)
                if !newValue {
                    self?.password = ""
                }
            }
            .store(in: &cancellables)
        
        $password
            .dropFirst()
            .sink { [weak self] newValue in
                self?.checkData(observedPassword: newValue)
            }
            .store(in: &cancellables)
        
        $enableExpirationDate
            .dropFirst()
            .sink { [weak self] newValue in
                self?.checkData(observedEnableExpiration: newValue)
            }
            .store(in: &cancellables)
        
        $expirationDate
            .dropFirst()
            .sink { [weak self] newValue in
                self?.checkData(observedExpirationDate: newValue)
            }
            .store(in: &cancellables)
    }
    
    private func checkData(
        observedEnablePassword: Bool? = nil,
        observedPassword: String? = nil,
        observedEnableExpiration: Bool? = nil,
        observedExpirationDate: Date? = nil
    ) {
        let tmp = DataStorage(
            enablePassword: observedEnablePassword ?? enablePassword,
            password: observedPassword ?? password,
            enableExpiration: observedEnableExpiration ?? enableExpirationDate,
            expirationDate: observedExpirationDate ?? expirationDate
        )
        guard let initialData else { return }
        hasChange = initialData.isDifferent(from: tmp)
    }
}

extension PublicLinkSettingViewModel {
    private struct DataStorage {
        let enablePassword: Bool
        let password: String
        let enableExpiration: Bool
        let expirationDate: Date
        
        func isPasswordChanged(from newData: DataStorage) -> Bool {
            var passwordHasChanged = false
            switch (enablePassword, newData.enablePassword) {
            case (true, true):
                passwordHasChanged = password != newData.password
            case (true, false):
                passwordHasChanged = true
            case (false, true):
                passwordHasChanged = !newData.password.isEmpty
            case (false, false):
                passwordHasChanged = false
            }
            return passwordHasChanged
        }
        
        func isExpirationChanged(from newData: DataStorage) -> Bool {
            var expirationHasChanged = false
            switch (enableExpiration, newData.enableExpiration) {
            case (true, true):
                expirationHasChanged = expirationDate != newData.expirationDate
            case (true, false):
                expirationHasChanged = true
            case (false, true):
                expirationHasChanged = true
            case (false, false):
                expirationHasChanged = false
            }
            return expirationHasChanged
        }
        
        func isDifferent(from newData: DataStorage) -> Bool {
            isPasswordChanged(from: newData) || isExpirationChanged(from: newData)
        }
    }
    
    struct Dependencies {
        let coordinator: SharingMemberCoordinatorProtocol
        let messageHandler: UserMessageHandlerProtocol
        let sharedLinkRepository: SharedLinkRepository
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
