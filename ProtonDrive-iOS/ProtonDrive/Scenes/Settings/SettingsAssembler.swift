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
import PDCoreIOS
import ProtonCoreAccountRecovery
import ProtonCoreAccountDeletion
import ProtonCoreDataModel
import ProtonCoreFeatureFlags
import ProtonCoreNetworking
import ProtonCoreServices
import ProtonCorePasswordChange
import PDLocalization
import LocalAuthentication

final class SettingsAssembler {

    private init() { }

    @MainActor
    static func assemble(apiService: APIService, tower: Tower, keymaker: Keymaker, photosContainer: PhotosSettingsContainer, featureFlagsController: FeatureFlagsControllerProtocol) -> UIViewController {
        let appSettings = makeAppSettings(tower: tower, keymaker: keymaker, photosContainer: photosContainer, featureFlagsController: featureFlagsController)

        let about = PMSettingsSectionViewModel.about
            .amending()
            .prepend(row: PMAcknowledgementsConfiguration.acknowledgements(url: Self.url))
            .amend()

        let accountSettings = PMSettingsSectionBuilder()
            .title(Localization.setting_account_settings.uppercased())
            .appendRowIfAvailable(
                changePasswordRow(isLoginPassword: true, tower: tower, apiService: apiService)
            )
            .appendRowIfAvailable(
                changePasswordRow(isLoginPassword: false, tower: tower, apiService: apiService)
            )
            .appendRowIfAvailable(
                securityKeysRow(apiService: apiService)
            )
            .appendRowIfAvailable(
                signInToAnotherDeviceRow(tower: tower, apiService: apiService)
            )
            .build()

        let localOptions = PMSettingsSectionBuilder()
            .appendRowIfAvailable(seeLatestLogsButton(tower.localSettings))
            .appendRowIfAvailable(enableDebugMode(tower.localSettings, featureFlagsController: featureFlagsController))
            .appendRowIfAvailable(exportLogsButton(tower.localSettings))
            .appendRowIfAvailable(clearLogsButton(tower.localSettings))
            .appendRow(clearCacheButton)
            .build()

        let accountRecovery = tower.sessionVault.getAccountInfo()?.accountRecovery
        let accountManagementSettings = PMSettingsSectionBuilder()
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
        if showAccountSection(coreCredential: tower.sessionVault.sessionCredential) {
            sections = [appSettings, about, localOptions, accountSettings, accountManagementSettings]
        } else {
            sections = [appSettings, about, localOptions, accountManagementSettings]
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
            text: Localization.setting_export_logs,
            action: {
                let logsURL = await LogExporter().export()
                await presentShareViewController(logs: logsURL)
            },
            bundle: Bundle.main
        )
        return configuration
    }

    static func clearLogsButton(_ featureFlags: LocalSettings) -> PMCellSuplier? {
        guard featureFlags.driveiOSLogCollection == true else { return nil }
        let configuration = PMLoadingLabelConfiguration(
            text: Localization.setting_clear_logs,
            action: {
                NotificationCenter.default.post(name: .nukeLogs)
            },
            bundle: Bundle.main
        )
        return configuration
    }

    static func enableDebugMode(_ featureFlags: LocalSettings, featureFlagsController: FeatureFlagsControllerProtocol) -> PMCellSuplier? {
        guard featureFlagsController.hasDebugMode else { return nil }
        let viewModel = BaseDrillDownCellViewModel(title: Localization.setting_debug_mode, preview: nil)

        return PMDrillDownConfiguration(viewModel: viewModel) {
            let vm = DebugModeSettingsViewModel(localSettings: featureFlags)
            let vc = UIHostingController(rootView: DebugModeSettingsView(viewModel: vm))
            vc.title = Localization.setting_debug_mode
            return vc
        }
    }

    static func seeLatestLogsButton(_ featureFlags: LocalSettings) -> PMCellSuplier? {
        guard featureFlags.driveiOSLogCollection == true && featureFlags.driveiOSLogCollectionDisabled == false else { return nil }
        return LatestLogsAssembler.assemble()
    }

    @MainActor
    static func presentShareViewController(logs: URL) {
        let shareActivity = UIActivityViewController(activityItems: [logs], applicationActivities: nil)
        shareActivity.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                try? FileManager.default.removeItem(at: PDFileManager.logsExportDirectory)
            }
        }
        guard let topVC = UIApplication.shared.topViewController()  else { return }
        if let popover = shareActivity.popoverPresentationController,
           let screenSize = topVC.view.realScreenSize() {
            // popover position will be updated after orientation change
            // check SideMenuCoordinator.orientationDidChange
            popover.sourceView = topVC.view
            popover.permittedArrowDirections = []
            let point = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
            popover.sourceRect = CGRect(origin: point, size: .zero)
        }
        topVC.present(shareActivity, animated: true)
    }

    static var clearCacheButton: PMCellSuplier {
        PMLoadingLabelConfiguration(
            text: Localization.setting_clear_local_cache,
            action: {
                NotificationCenter.default.nukeCache(reason: "User clear cache")
            },
            bundle: .main
        )
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

    /// Provides the Account Recovery row for the settings, provided the FF is enabled
    static func securityKeysRow(apiService: APIService) -> PMDrillDownConfiguration? {
        let item = SecurityKeysSettingsItem(apiService: apiService)
        return PMDrillDownConfiguration(viewModel: item,
                                        viewControllerFactory: { item.controller })
    }

    @MainActor
    /// Provides the Sign in to another device row for the settings, provided the FF is enabled
    static func signInToAnotherDeviceRow(tower: Tower, apiService: APIService) -> PMDrillDownConfiguration? {
        guard let accountInfo = tower.sessionVault.getAccountInfo(),
              let passphrase = try? tower.sessionVault.getUserPassphrase(),
              let userInfo = buildCoreUserInfo(tower: tower),
              isSignInToAnotherDeviceEnabled(userInfo: userInfo) else {
            return nil
        }

        let item = SignInToAnotherDeviceItem(apiService: apiService, passphrase: passphrase, email: accountInfo.email)
        return PMDrillDownConfiguration(viewModel: item,
                                        viewControllerFactory: { item.controller })
    }

    static func isSignInToAnotherDeviceEnabled(userInfo: ProtonCoreDataModel.UserInfo?) -> Bool {
        let qrLoginOptedOut = userInfo?.edmOptOut == 1
        let qrLoginFeatureDisabled = FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.easyDeviceMigrationDisabled)
        let isDeviceSecured: Bool = {
#if targetEnvironment(simulator)
            return true
#else
            let context = LAContext()
            var error: NSError?

            return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
#endif
        }()

        return !qrLoginOptedOut && !qrLoginFeatureDisabled && isDeviceSecured
    }
}

// MARK: - App Settings
extension SettingsAssembler {
    @MainActor
    private static func makeAppSettings(
        tower: Tower,
        keymaker: Keymaker,
        photosContainer: PhotosSettingsContainer,
        featureFlagsController: FeatureFlagsControllerProtocol
    ) -> PMSettingsSectionViewModel {
        
        return PMSettingsSectionBuilder()
            .title(Localization.setting_app_settings.uppercased())
            .appendRow(makePinButton(tower: tower, keymaker: keymaker))
            .appendRow(photosContainer.makeSettingsCell())
            .appendRow(languageButton())
            .appendRow(DefaultHomeTabFactory.defaultHomeTabRow(tower: tower, featureFlags: featureFlagsController))
            .build()
    }
    
    private static func makePinButton(tower: Tower, keymaker: Keymaker) -> PMCellSuplier {
        PMPinFaceIDDrillDownCellConfiguration.security(
            locker: keymaker
        ) {
            !(tower.localSettings.photosUploadDisabledValue == true)
        }
    }

    private static func languageButton() -> PMCellSuplier {
        let viewModel = BaseDrillDownCellViewModel(title: Localization.setting_language, preview: nil)
        return PMActionableDrillDownConfiguration(viewModel: viewModel) { _, _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }
    }
}

// MARK: - Password Change
extension SettingsAssembler {
    static func showAccountSection(coreCredential: CoreCredential?) -> Bool {
        isChangePasswordEnabled(coreCredential: coreCredential)
    }

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
