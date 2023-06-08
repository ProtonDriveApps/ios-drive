//
//  MailboxPasswordViewModel.swift
//  ProtonCore-Login - Created on 30.11.2020.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ProtonCore_Log
import ProtonCore_Login

final class MailboxPasswordViewModel {
    enum MailboxPasswordResult {
        case done(LoginData)
        case createAddressNeeded(CreateAddressData, String?)
    }

    // MARK: - Properties

    let finished = Publisher<MailboxPasswordResult>()
    let error = Publisher<LoginError>()
    let isLoading = Observable<Bool>(false)

    private let login: Login

    init(login: Login) {
        self.login = login
    }

    // MARK: - Actions

    func unlock(password: String) {
        isLoading.value = true
        // we know that password mode is .two because we are in the MailboxPasswordViewModel, shown only when there's a second password needed
        login.finishLoginFlow(mailboxPassword: password, passwordMode: .two) { [weak self] result in
            switch result {
            case let .failure(error):
                self?.error.publish(error)
                self?.isLoading.value = false
            case let .success(status):
                switch status {
                case let .finished(data):
                    self?.finished.publish(.done(data))
                case let .chooseInternalUsernameAndCreateInternalAddress(data):
                    self?.login.checkUsernameFromEmail(email: data.email) { [weak self] result in
                        switch result {
                        case .failure(let error):
                            self?.error.publish(.generic(message: error.messageForTheUser, code: error.bestShotAtReasonableErrorCode, originalError: error))
                        case .success(let defaultUsername):
                            self?.finished.publish(.createAddressNeeded(data, defaultUsername))
                        }
                        self?.isLoading.value = false
                    }
                case .ask2FA, .askSecondPassword:
                    PMLog.error("Invalid state \(status) after entering Mailbox password")
                    self?.error.publish(.invalidState)
                    self?.isLoading.value = false
                }
            }
        }
    }
}
