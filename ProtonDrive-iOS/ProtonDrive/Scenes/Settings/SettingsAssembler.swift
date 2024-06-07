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

import SwiftUI
import PMSettings
import ProtonCoreKeymaker
import PDCore

import ProtonCoreAccountRecovery
import ProtonCoreAccountDeletion
import ProtonCoreDataModel
import ProtonCoreFeatureFlags
import ProtonCoreNetworking
import ProtonCoreServices
import ProtonCorePasswordChange

final class SettingsAssembler {

    private init() { }

    @MainActor
    static func assemble(apiService: APIService, tower: Tower, keymaker: Keymaker, photosContainer: PhotosSettingsContainer?) -> UIViewController {
        var appSettings = PMSettingsSectionViewModel.appSettings(with: keymaker)
        let accountRecovery = tower.sessionVault.getAccountInfo()?.accountRecovery

        if let photosContainer = photosContainer {
            appSettings = appSettings
                .amending()
                .append(row: photosContainer.makeSettingsCell())
                .amend()
        }
        let about = PMSettingsSectionViewModel.about
            .amending()
            .prepend(row: PMAcknowledgementsConfiguration.acknowledgements(url: Self.url))
            .amend()

        let changePassword = PMSettingsSectionBuilder(bundle: PMSettings.bundle)
            .title("pmsettings-settings-account-settings-section")
            .appendRowIfAvailable(
                changePasswordRow(isLoginPassword: true, tower: tower, apiService: apiService)
            )
            .appendRowIfAvailable(
                changePasswordRow(isLoginPassword: false, tower: tower, apiService: apiService)
            )
            .build()

        let localOptions = PMSettingsSectionBuilder(bundle: PMSettings.bundle)
            .appendRowIfAvailable(exportLogsButton(tower.localSettings))
            .appendRow(clearCacheButton)
            .build()

        let accountSettings = PMSettingsSectionBuilder(bundle: PMSettings.bundle)
            .title(accountRecovery?.title)
            .footer(ADTranslation.delete_account_message.l10n)
            .appendRowIfAvailable(
                accountRecoveryRow(apiService: apiService,
                                   accountRecovery: accountRecovery)
            )
            .appendRow(PMHostConfiguration(
                viewController: makeDeleteAccountViewController(apiService: apiService, signoutManager: tower))
            )
            .build()

        var sections: [PMSettingsSectionViewModel]
        if isChangePasswordEnabled(coreCredential: tower.sessionVault.sessionCredential) {
            sections = [appSettings, about, localOptions, changePassword, accountSettings]
        } else {
            sections = [appSettings, about, localOptions, accountSettings]
        }

        return PMSettingsComposer.assemble(
            sections: sections,
            leftBarButtonAction: PMSettingsLeftBarButton(
                image: UIImage(named: "ic-hamburger"),
                action: { NotificationCenter.default.post(.toggleSideMenu) }
            )
        )
    }

    static func makeDeleteAccountViewController(apiService: APIService, signoutManager: SignOutManager) -> DeleteAccountViewController {
        let accountViewModel = DeleteAccountViewModel(apiService: apiService, signoutManager: signoutManager)
        return DeleteAccountViewController(viewModel: accountViewModel)
    }

    static func securityCell(with keymaker: Keymaker) -> PMCellSuplier {
        PMPinFaceIDDrillDownCellConfiguration.security(locker: makeLockManager(with: keymaker))
    }

    static func makeLockManager(with keymaker: Keymaker) -> KeymakerLockManager {
        return KeymakerLockManager(
            lockReader: keymaker,
            pinLocker: keymaker,
            bioLocker: keymaker,
            autoLocker: keymaker)
    }

    static var url: URL {
        Bundle.main.url(forResource: "Acknowledgements", withExtension: "markdown")!
    }

    static func exportLogsButton(_ featureFlags: LocalSettings) -> PMCellSuplier? {
        guard featureFlags.driveiOSLogCollection == true && featureFlags.driveiOSLogCollectionDisabled == false else { return nil }
        let configuration = PMLoadingLabelConfiguration(
            text: "Export Logs",
            action: {
                let logsURL = await LogExporter().export()
                await presentShareViewController(logs: logsURL)
            },
            bundle: Bundle.main
        )
        return configuration
    }

    @MainActor
    static func presentShareViewController(logs: URL) {
        let shareActivity = UIActivityViewController(activityItems: [logs], applicationActivities: nil)
        shareActivity.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: PDFileManager.logsExportDirectory)
        }

        UIApplication.shared.topViewController()?.present(shareActivity, animated: true)
    }

    static var clearCacheButton: PMAboutConfiguration {
        PMAboutConfiguration(title: "Clear local cache", action: .perform({
            NotificationCenter.default.post(name: .nukeCache, object: nil)
        }), bundle: .main)
    }

    /// Provides the Account Recovery row for the settings, provided the FF is enabled
    static func accountRecoveryRow(apiService: APIService, accountRecovery: AccountRecovery?) -> PMDrillDownConfiguration? {
        guard FeatureFlagsRepository.shared.isEnabled(
            CoreFeatureFlagType.accountRecovery
        ) else { return nil }

        guard let accountRecovery else { return nil }

        let item = AccountRecoverySettingsItem(apiService: apiService, accountRecovery: accountRecovery)
        return PMDrillDownConfiguration(viewModel: item,
                                        viewControllerFactory: { item.controller })
    }
}

// MARK: - Password Change
extension SettingsAssembler {
    static func isChangePasswordEnabled(coreCredential: CoreCredential?) -> Bool {
        guard let coreCredential,
              !coreCredential.mailboxPassword.isEmpty else {
            return false
        }
        return FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.changePassword, reloadValue: true)
    }

    /// Provides the ChangePassword row for the settings, provided the FF is enabled
    @MainActor
    static func changePasswordRow(
        isLoginPassword: Bool,
        tower: Tower,
        apiService: APIService
    ) -> PasswordChangeDrillDownConfiguration? {
        guard let coreCredential = tower.sessionVault.sessionCredential,
              isChangePasswordEnabled(coreCredential: coreCredential),
              let userInfo = buildCoreUserInfo(tower: tower),
              let mode = passwordChangeMode(isLoginPassword: isLoginPassword, userInfo: userInfo) else {
            return nil
        }

        let item = PasswordChangeSettingsViewModel(
            mode: mode,
            sessionVault: tower.sessionVault,
            sessionCommunicator: tower.sessionCommunicator,
            apiService: apiService,
            coreCredential: coreCredential,
            userInfo: userInfo
        )
        return PasswordChangeDrillDownConfiguration(viewModel: item,
                                                    viewControllerFactory: { item.controller })
    }

    private static func buildCoreUserInfo(tower: Tower) -> ProtonCoreDataModel.UserInfo? {
        guard let userInfo = tower.sessionVault.getCoreUserInfo(),
              let userSettings = tower.generalSettings.currentUserSettings else {
            return nil
        }
        userInfo.passwordMode = userSettings.passwordMode
        userInfo.twoFactor = userSettings.twoFA.enabled
        return userInfo
    }

    private static func passwordChangeMode(isLoginPassword: Bool, userInfo: ProtonCoreDataModel.UserInfo) -> PasswordChangeModule.PasswordChangeMode? {
        // passwordMode == 1 means single password, 2 means login + mailbox password
        if isLoginPassword {
            return userInfo.passwordMode == 1 ? .singlePassword : .loginPassword
        } else if userInfo.passwordMode == 2 {
            return .mailboxPassword
        } else {
            return nil
        }
    }
}

// MARK: - Pin locking
extension Keymaker: PinLocker { }

extension Keymaker: PinLockActivator {
    public func activatePin(pin: String, completion: @escaping (Bool) -> Void) {
        let protector = PinProtection(pin: pin, keychain: DriveKeychain.shared)
        activate(protector, completion: completion)
    }
}

extension Keymaker: PinLockDeactivator {
    public func deactivatePin(completion: @escaping (Bool) -> Void) {
        // pin string here is just a placeholder, it is never used in the deactivation flow
        let protector = PinProtection(pin: "-", keychain: DriveKeychain.shared)
        let success = deactivate(protector)
        completion(success)
    }
}

// MARK: - Bio locking
extension Keymaker: BioLocker { }

extension Keymaker: BioLockActivator {
    public func activateBio(completion: @escaping (Bool) -> Void) {
        let protector = BioProtection(keychain: DriveKeychain.shared)
        activate(protector, completion: completion)
    }
}

extension Keymaker: BioLockDeactivator {
    public func deactivateBio(completion: @escaping (Bool) -> Void) {
        let protector = BioProtection(keychain: DriveKeychain.shared)
        let success = deactivate(protector)
        completion(success)
    }
}
