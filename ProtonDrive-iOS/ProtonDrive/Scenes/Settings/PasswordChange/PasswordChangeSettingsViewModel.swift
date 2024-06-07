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
import PMSettings
import PDCore
import ProtonCoreDataModel
import ProtonCoreNetworking
import ProtonCorePasswordChange
import ProtonCoreServices

class PasswordChangeSettingsViewModel: PMDrillDownCellViewModel {
    var preview: String? { nil }
    var title: String {
        mode == .mailboxPassword ?
        "Change mailbox password" :
        "Change password"
    }

    var parentViewController: UIViewController?

    let mode: PasswordChangeModule.PasswordChangeMode
    let sessionVault: SessionVault
    let sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions
    let apiService: APIService
    let coreCredential: CoreCredential
    let userInfo: ProtonCoreDataModel.UserInfo

    init(
        mode: PasswordChangeModule.PasswordChangeMode,
        sessionVault: SessionVault,
        sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions,
        apiService: APIService,
        coreCredential: CoreCredential,
        userInfo: ProtonCoreDataModel.UserInfo
    ) {
        self.mode = mode
        self.sessionVault = sessionVault
        self.sessionCommunicator = sessionCommunicator
        self.apiService = apiService
        self.coreCredential = coreCredential
        self.userInfo = userInfo
    }

    @MainActor
    var controller: PasswordChangeViewController {
        PasswordChangeModule.makePasswordChangeViewController(
            mode: mode,
            apiService: apiService,
            authCredential: coreCredential.toAuthCredential(),
            userInfo: userInfo
        ) { [weak self] authCredential, newUserInfo in
            guard let self else { return }
            self.processPasswordChangeSuccess(authCredential: authCredential, newUserInfo: newUserInfo)
        }
    }

    func processPasswordChangeSuccess(authCredential: AuthCredential, newUserInfo: ProtonCoreDataModel.UserInfo) {
        let newCredential = Credential(authCredential, scopes: coreCredential.scope)
        sessionCommunicator.fetchNewChildSession(parentSessionCredential: newCredential) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                do {
                    self.sessionVault.storeCredential(CoreCredential(newCredential))
                    self.sessionVault.storeAddresses(newUserInfo.userAddresses)
                    if var user = self.sessionVault.getUser() {
                        user.keys = newUserInfo.userKeys
                        sessionVault.storeUser(user)
                    }

                    try sessionVault.updatePassphrases(
                        for: newUserInfo.userKeys.filter { $0.isUpdated },
                        mailboxPassphrase: newCredential.mailboxPassword
                    )

                    Task { @MainActor [weak self] in
                        self?.parentViewController?.navigationController?.popToRootViewController(animated: true)
                        NotificationCenter.default.post(name: .banner, object: BannerModel.info("Password changed successfully"))
                    }
                    sessionCommunicator.onChildSessionReady()
                } catch {
                    Log.error(error.localizedDescription, domain: .application)
                    NotificationCenter.default.post(.signOut)
                }
            case .failure(let error):
                Log.error(error.localizedDescription, domain: .sessionManagement)
            }
        }
    }
}
