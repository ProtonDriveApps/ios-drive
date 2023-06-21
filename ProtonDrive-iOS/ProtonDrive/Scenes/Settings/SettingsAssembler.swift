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
import ProtonCore_Settings
import ProtonCore_Keymaker
import ProtonCore_CoreTranslation
import PDCore
import ProtonCore_Services
import ProtonCore_AccountDeletion

final class SettingsAssembler {

    private init() { }

    static func assemble(apiService: APIService, tower: Tower, keymaker: Keymaker, photosContainer: PhotosSettingsContainer?) -> UIViewController {
        var appSettings = PMSettingsSectionViewModel.appSettings(with: keymaker)
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
        let clearCache = PMSettingsSectionBuilder(bundle: PMSettings.bundle)
            .appendRow(
                PMAboutConfiguration(title: "Clear local cache", action: .perform({
                    NotificationCenter.default.post(name: .nukeCache, object: nil)
                }), bundle: .main)
            )
            .build()
        let accountSettings = PMSettingsSectionBuilder(bundle: PMSettings.bundle)
            .footer(CoreString._ad_delete_account_message)
            .appendRow(PMHostConfiguration(
                viewController: makeDeleteAccountViewController(apiService: apiService, signoutManager: tower))
            )
            .build()
        return PMSettingsComposer.assemble(
            sections: [appSettings, about, clearCache, accountSettings],
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
}

// MARK: - Pin locking
extension Keymaker: PinLocker { }

extension Keymaker: PinLockActivator {
    public func activatePin(pin: String, completion: @escaping (Bool) -> Void) {
        let protector = PinProtection(pin: pin, keychain: DriveKeychain())
        activate(protector, completion: completion)
    }
}

extension Keymaker: PinLockDeactivator {
    public func deactivatePin(completion: @escaping (Bool) -> Void) {
        // pin string here is just a placeholder, it is never used in the deactivation flow
        let protector = PinProtection(pin: "-", keychain: DriveKeychain())
        let success = deactivate(protector)
        completion(success)
    }
}

// MARK: - Bio locking
extension Keymaker: BioLocker { }

extension Keymaker: BioLockActivator {
    public func activateBio(completion: @escaping (Bool) -> Void) {
        let protector = BioProtection(keychain: DriveKeychain())
        activate(protector, completion: completion)
    }
}

extension Keymaker: BioLockDeactivator {
    public func deactivateBio(completion: @escaping (Bool) -> Void) {
        let protector = BioProtection(keychain: DriveKeychain())
        let success = deactivate(protector)
        completion(success)
    }
}
