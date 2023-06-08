//
//  LoginService+Migration.swift
//  ProtonCore-Login - Created on 20/05/2021.
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
import ProtonCore_Authentication
import ProtonCore_APIClient
import ProtonCore_DataModel
import ProtonCore_Log
import ProtonCore_Networking
import ProtonCore_FeatureSwitch
import ProtonCore_CoreTranslation

// these methods are responsible for fetching and refreshing the data: user, addresses, keys, salts etc.
// in case we detect the need for account migration, it's also performed (if possible, otherwise process fails with error)

extension LoginService {

    func getAccountDataPerformingAccountMigrationIfNeeded(
        user: User, mailboxPassword: String, passwordMode: PasswordMode, completion: @escaping (Result<LoginStatus, LoginError>) -> Void
    ) {
        // first login of a private user who has not changed the default password yet
        if user.keys.isEmpty, user.role == 1, user.private == 1 {
            completion(.failure(.needsFirstTimePasswordChange))
            return
        }

        // if there is no key and user is not private return an error
        if user.keys.isEmpty, user.private == 0 {
            completion(.failure(.missingSubUserConfiguration))
            return
        }

        // external account used but internal needed
        // account migration needs to take place and we cannot do it automatically because user has not chosen the internal username yet
        if user.isExternal, self.minimumAccountType == .internal {

            // Cap C blocked
            guard isCapCEnabled(completion: completion) else { return }

            // external to internal conversion flow kick-off
            withAuthDelegateAvailable(completion) { authManager in
                completion(.success(.chooseInternalUsernameAndCreateInternalAddress(CreateAddressData(email: self.username!, credential: authManager.authCredential(sessionUID: sessionId)!, user: user, mailboxPassword: mailboxPassword, passwordMode: passwordMode))))
            }
            return
        }

        self.fetchAddressesAndEncryptionDataPerformingAutomaticAccountMigrationIfNeeded(
            user: user, mailboxPassword: mailboxPassword, passwordMode: passwordMode, completion: completion
        )
    }

    private func fetchAddressesAndEncryptionDataPerformingAutomaticAccountMigrationIfNeeded(
        user: User, mailboxPassword: String, passwordMode: PasswordMode, completion: @escaping (Result<LoginStatus, LoginError>) -> Void
    ) {
        manager.getAddresses { [weak self] result in
            switch result {
            case .failure(let error):
                PMLog.error("Cannot fetch addresses for user")
                completion(.failure(error.asLoginError()))

            case .success(let addresses):
                self?.fetchEncryptionDataPerformingAutomaticAccountMigrationIfNeeded(
                    addresses: addresses, user: user, mailboxPassword: mailboxPassword, passwordMode: passwordMode, completion: completion
                )
            }
        }
    }
    
    private func fetchEncryptionDataPerformingAutomaticAccountMigrationIfNeeded(
        addresses: [Address], user: User, mailboxPassword: String, passwordMode: PasswordMode, completion: @escaping (Result<LoginStatus, LoginError>) -> Void
    ) {
        let hasAnyInternalAddress = addresses.first(where: { $0.type != .externalAddress }) != nil
        let hasNoAddressesAtAll = addresses.isEmpty
        let hasAtLeastOneAddress = !hasNoAddressesAtAll
        let hasExternalAddressAndNoInternalOnes = !hasAnyInternalAddress && hasAtLeastOneAddress
        let hasNoKeys = user.keys.isEmpty

        // user has no addresses but username — username account. If the app supports the username account, we finish right away
        let isUsernameAccountAndAppSupportsIt = user.isInternal && hasNoAddressesAtAll && minimumAccountType == .username
        // user has second password mode (we need to check for keys as well) but the app doesn't need keys, we finish right away
        let hasSecondPasswordButAppDoesNotNeedKeys = passwordMode == .two && !hasNoKeys && minimumAccountType == .username

        if isUsernameAccountAndAppSupportsIt || hasSecondPasswordButAppDoesNotNeedKeys {
            withAuthDelegateAvailable(completion) { authManager in
                guard let credentials = authManager.credential(sessionUID: sessionId),
                      let authCredentials = authManager.authCredential(sessionUID: sessionId) else {
                    completion(.failure(.invalidState))
                    return
                }
                completion(.success(.finished(
                    UserData(credential: authCredentials, user: user, salts: [], passphrases: [:], addresses: addresses, scopes: credentials.scopes)
                )))
            }
            return
        }
        
        // when external user has no key. external address is not empty. try to create keys only. other logic stays the same
        if hasNoKeys, user.isExternal, hasExternalAddressAndNoInternalOnes {
            
            self.createAccountKeysIfNeeded(user: user,
                                           addresses: addresses,
                                           mailboxPassword: mailboxPassword) { [weak self] result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let updatedUser):
                    // if the user had no keys, it means that the password mode was .two while there is no actual second password
                    // therefore we need to overwrite the original password mode with the .one value
                    let passwordModeAfterAccountKeyCreation: PasswordMode = .one
                    // after the keys generation — re-fetch the addresses and continue the flow
                    self?.fetchAddressesAndEncryptionDataPerformingAutomaticAccountMigrationIfNeeded(
                        user: updatedUser,
                        mailboxPassword: mailboxPassword,
                        passwordMode: passwordModeAfterAccountKeyCreation,
                        completion: completion
                    )
                }
            }
            return
        }

        // when the user has no keys and either
        if hasNoKeys, hasAnyInternalAddress || hasNoAddressesAtAll || (user.isInternal && hasExternalAddressAndNoInternalOnes) {

            // automatic account migration needed: keys must be generated
            setupAccountKeysAndCreateInternalAddressIfNeeded(
                user: user, addresses: addresses, mailboxPassword: mailboxPassword
            ) { [weak self] result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let updatedUser):
                    // if the user had no keys, it means that the password mode was .two while there is no actual second password
                    // therefore we need to overwrite the original password mode with the .one value
                    let passwordModeAfterAccountKeyCreation: PasswordMode = .one
                    // after the keys generation — fetch the fresh data and retry the process
                    self?.fetchAddressesAndEncryptionDataPerformingAutomaticAccountMigrationIfNeeded(
                        user: updatedUser,
                        mailboxPassword: mailboxPassword,
                        passwordMode: passwordModeAfterAccountKeyCreation,
                        completion: completion
                    )
                }
            }
            return
        }

        guard !hasNoKeys, hasAtLeastOneAddress else {
            // user has keys, but doesn't have any address. I won't try to create the internal address automatically.
            // I believe it'd be dead code that handles the path that, if appears, indicated the invalid state
            completion(.failure(.invalidState))
            return
        }

        // user has keys and there are addresses. however, we do not know if:
        // 1. they have the right address for the minimumAccountType requirement
        // 2. if the address has the keys generated (the user keys might be for address other than minimumAccountType require)
        // 3. there are any active addresses that we should generate the keys for

        switch minimumAccountType {
        case .username, .external:
            let activeAddresses = addresses.filter { $0.status != .disabled }
            // I there are no active addresses that we can generate the keys for, just return
            if activeAddresses.isEmpty {
                withAuthDelegateAvailable(completion) { authManager in
                    guard let authCredential = authManager.authCredential(sessionUID: sessionId),
                          let credential = authManager.credential(sessionUID: sessionId) else {
                        completion(.failure(.invalidState))
                        return
                    }
                    completion(.success(.finished(
                        UserData(credential: authCredential, user: user, salts: [], passphrases: [:], addresses: addresses, scopes: credential.scopes)
                    )))
                }
                return
            }

            fetchEncryptionDataEnsuringAllAddressesHaveKeys(addresses: addresses, user: user, mailboxPassword: mailboxPassword, passwordMode: passwordMode, completion: completion)

        case .internal:
            fetchEncryptionDataForInternalAccountRequirementPerformingAutomaticAccountMigrationIfNeeded(
                addresses: addresses, user: user, mailboxPassword: mailboxPassword, passwordMode: passwordMode, completion: completion
            )
        }
    }

    // this method is responsible for creating account keys in case the account has no keys and for creating the internal address if it's needed
    // this method is NOT responsible for checking if the addresses have keys generated nor for generating them
    private func setupAccountKeysAndCreateInternalAddressIfNeeded(user: User,
                                                                  addresses: [Address],
                                                                  mailboxPassword: String,
                                                                  completion: @escaping (Result<User, LoginError>) -> Void) {
        PMLog.debug("Upgrading account without keys and possibly without internal address to account with keys and internal address if needed")

        guard user.keys.isEmpty else {
            assertionFailure("This method should never be called for the account that has the keys already generated")
            completion(.failure(.invalidState))
            return
        }

        // first check if the account already has an internal or custom domain address
        let internalOrCustomDomain = addresses.internalOrCustomDomain
        guard internalOrCustomDomain.isEmpty else {
            // if internal or custom domain address already exists, the only work left is to create up account keys if needed
            self.createAccountKeysIfNeeded(user: user, addresses: addresses, mailboxPassword: mailboxPassword, completion: completion)
            return
        }

        switch self.minimumAccountType {
        case .username:
            assertionFailure("Setup account keys and address should never be called form username accounts")
            completion(.failure(.invalidState))

        case .internal:
            guard user.isInternal else {
                // there is no address but the user is external, so we cannot automatically create one. let's finish with an invalid state
                completion(.failure(.invalidState))
                return
            }

            // create internal address because there is none while it's required by minimumAccountType == .internal to have at least one
            self.createAddress { result in
                switch result {
                case let .success(address), let .failure(.alreadyHaveInternalOrCustomDomainAddress(address)):
                    self.createAccountKeysIfNeeded(user: user,
                                                   addresses: (addresses + [address]).uniques(by: \.addressID),
                                                   mailboxPassword: mailboxPassword,
                                                   completion: completion)
                case let .failure(.generic(message, code, originalError)):
                    completion(.failure(.generic(message: message, code: code, originalError: originalError)))
                case let .failure(.apiMightBeBlocked(message, originalError)):
                    completion(.failure(.apiMightBeBlocked(message: message, originalError: originalError)))
                case let .failure(error):
                    completion(.failure(.generic(message: error.userFacingMessageInLogin, code: error.codeInLogin, originalError: error)))
                }
            }

        case .external:

            guard addresses.isEmpty else {
                // the user has the address and the minimumAccountType == .external doesn't care if it's external or internal address
                // let's just make the account keys if needed
                self.createAccountKeysIfNeeded(user: user,
                                               addresses: addresses,
                                               mailboxPassword: mailboxPassword,
                                               completion: completion)
                return
            }

            guard user.isInternal else {
                // there is no address but the user is external, so we cannot automatically create one. let's finish with an invalid state
                completion(.failure(.invalidState))
                return
            }

            // there are no addresses, however, we're lucky — the user has a name, so we can create an internal address automatically
            self.createAddress { result in
                switch result {
                case let .success(address), let .failure(.alreadyHaveInternalOrCustomDomainAddress(address)):
                    self.createAccountKeysIfNeeded(user: user,
                                                   addresses: [address],
                                                   mailboxPassword: mailboxPassword,
                                                   completion: completion)
                case let .failure(.apiMightBeBlocked(message, originalError)):
                    completion(.failure(.apiMightBeBlocked(message: message, originalError: originalError)))
                case let .failure(error):
                    completion(.failure(.generic(message: error.userFacingMessageInLogin, code: error.codeInLogin, originalError: error)))
                }
            }
        }
    }

    private func fetchEncryptionDataForInternalAccountRequirementPerformingAutomaticAccountMigrationIfNeeded(
        addresses: [Address], user: User, mailboxPassword: String, passwordMode: PasswordMode, completion: @escaping (Result<LoginStatus, LoginError>) -> Void
    ) {
        // the account has no internal address while it's required by minimumAccountType == .internal. let's create it!
        guard addresses.hasInternalOrCustomDomain else {

            guard user.isInternal else {
                assertionFailure("This method should never be called for this scenario. It should be handled by returning .chooseInternalUsernameAndCreateInternalAddress at the call site")
                completion(.failure(.invalidState))
                return

            }

            createAddress { [weak self] result in
                switch result {
                case let .success(address):
                    self?.createAddressKeyAndRefreshUserData(user: user, address: address, mailboxPassword: mailboxPassword, passwordMode: passwordMode, completion: completion)
                case let .failure(.apiMightBeBlocked(message, originalError)):
                    completion(.failure(.apiMightBeBlocked(message: message, originalError: originalError)))
                case let .failure(error):
                    PMLog.debug("Fetching user info with \(error)")
                    completion(.failure(.generic(message: error.userFacingMessageInLogin, code: error.codeInLogin, originalError: error)))
                }
            }
            return
        }

        fetchEncryptionDataEnsuringAllAddressesHaveKeys(
            addresses: addresses, user: user, mailboxPassword: mailboxPassword, passwordMode: passwordMode, completion: completion
        )
    }

    private func createAddressKeyAndRefreshUserData(user: User,
                                                    address: Address,
                                                    mailboxPassword: String,
                                                    passwordMode: PasswordMode,
                                                    completion: @escaping (Result<LoginStatus, LoginError>) -> Void) {

        createAddressKeys(user: user, address: address, mailboxPassword: mailboxPassword) { [weak self] result in

            func fetchUserDataAndRetryFetchingAddressesAndEncryptionData() {
                self?.manager.getUserInfo { [weak self] result in
                    switch result {
                    case .success(let updatedUser):
                        // after the address keys generation — retry fetching the data
                        self?.fetchAddressesAndEncryptionDataPerformingAutomaticAccountMigrationIfNeeded(
                            user: updatedUser, mailboxPassword: mailboxPassword, passwordMode: passwordMode, completion: completion
                        )
                    case .failure(let error):
                        completion(.failure(error.asLoginError()))
                    }
                }
            }

            switch result {
            case .success:
                fetchUserDataAndRetryFetchingAddressesAndEncryptionData()
            case let .failure(error):
                switch error {
                case .alreadySet:
                    PMLog.debug("Address keys already created, moving on")
                    fetchUserDataAndRetryFetchingAddressesAndEncryptionData()
                case let .generic(message, code, originalError):
                    PMLog.error("Cannot fetch addresses for user")
                    completion(.failure(.generic(message: message, code: code, originalError: originalError)))
                case let .apiMightBeBlocked(message, originalError):
                    PMLog.error("Cannot fetch addresses for user")
                    completion(.failure(.apiMightBeBlocked(message: message, originalError: originalError)))
                }
            }
        }
    }

    private func fetchEncryptionDataEnsuringAllAddressesHaveKeys(
        addresses: [Address], user: User, mailboxPassword: String, passwordMode: PasswordMode, completion: @escaping (Result<LoginStatus, LoginError>) -> Void
    ) {

        guard addresses.isEmpty == false else {
            assertionFailure("You should not call this method when there is no address. Check at the call site")
            completion(.failure(.invalidState))
            return
        }

        // we can only generate the key for the address of the private user (otherwise it should be the user's admin who does that)
        // we can only generate the key for the address that is active (not disabled) and that doesn't have keys
        if user.private == 1, let address = addresses.first(where: { $0.status != .disabled && ($0.hasKeys == 0 || $0.keys.isEmpty) }) {
            createAddressKeyAndRefreshUserData(user: user, address: address, mailboxPassword: mailboxPassword, passwordMode: passwordMode, completion: completion)
            return
        }

        // continue fetching all the data
        checkMissingKeysAndGetSalts(addresses: addresses, user: user, mailboxPassword: mailboxPassword, completion: completion)
    }

    private func checkMissingKeysAndGetSalts(addresses: [Address], user: User, mailboxPassword: String, completion: @escaping (Result<LoginStatus, LoginError>) -> Void) {
        let address: Address?

        switch minimumAccountType {
        case .username, .external:
            // Only if no internal address exists, identify an external address
            address = addresses.firstInternal ?? addresses.firstExternal
        case .internal: // for apps that require internal address
            address = addresses.firstInternal
        }

        // Check the value of "HasKeys" for whichever address has been identified from above (1 == true and the "Keys" array will be empty if HasKeys == 0)
        if address?.hasKeys == 1 {
            // no missing keys, continue with salts
            getSalts(addresses: addresses, user: user, mailboxPassword: mailboxPassword, completion: completion)
        } else {
            // missing keys (or address)
            assertionFailure("This scenario should never happen. To whoever calls this method: you must ensure the keys are generated before calling this and that the user has an address")
            completion(.failure(.missingKeys))
        }
    }

    private func getSalts(addresses: [Address], user: User, mailboxPassword: String, completion: @escaping (Result<LoginStatus, LoginError>) -> Void) {
        PMLog.debug("Fetching key salts")

        manager.getKeySalts { [weak self] result in
            switch result {
            case let .success(salts):
                self?.makesPassphrasesAndValidateMailboxPassword(addresses: addresses, user: user, mailboxPassword: mailboxPassword, salts: salts, completion: completion)
            case let .failure(error):
                PMLog.debug("Fetching key salts failed with \(error)")
                completion(.failure(error.asLoginError()))
            }
        }
    }

    private func makesPassphrasesAndValidateMailboxPassword(addresses: [Address], user: User, mailboxPassword: String, salts: [KeySalt], completion: @escaping (Result<LoginStatus, LoginError>) -> Void) {
        withAuthDelegateAvailable(completion) { authManager in
            PMLog.debug("Making passphrases")

            switch makePassphrases(salts: salts, mailboxPassword: mailboxPassword) {
            case let .success(passphrases):
                PMLog.debug("Validating mailbox password")

                guard validateMailboxPassword(passphrases: passphrases, userKeys: user.keys) else {
                    PMLog.debug("Validating mailbox password failed")
                    completion(.failure(.invalidSecondPassword))
                    return
                }

                if let key = user.keys.first(where: { $0.primary == 1 }) ?? user.keys.first {
                    authManager.onAdditionalCredentialsInfoObtained(
                        sessionUID: sessionId,
                        password: passphrases[key.keyID],
                        salt: salts.first { $0.ID == key.keyID }.flatMap { $0.keySalt },
                        privateKey: key.privateKey
                    )
                }

                guard let authCredentials = authManager.authCredential(sessionUID: sessionId),
                      let credentials = authManager.credential(sessionUID: sessionId) else {
                    completion(.failure(.invalidState))
                    return
                }

                completion(.success(.finished(UserData(credential: authCredentials,
                                                       user: user,
                                                       salts: salts,
                                                       passphrases: passphrases,
                                                       addresses: addresses,
                                                       scopes: credentials.scopes))))

            case let .failure(error):
                PMLog.debug("Making passphrases failed with \(error)")
                completion(.failure(.generic(message: error.messageForTheUser,
                                             code: error.bestShotAtReasonableErrorCode,
                                             originalError: error)))
            }
        }
    }
    
    private func isCapCEnabled(completion: @escaping (Result<LoginStatus, LoginError>) -> Void) -> Bool {
        guard FeatureFactory.shared.isEnabled(.externalAccountConversion) else {
            let localError = NSError.asProtonAddrRequiredError()
            completion(.failure(.externalAccountsNotSupported(
                message: CoreString._ls_external_accounts_not_supported_popup_local_desc, title: CoreString._ls_external_accounts_address_required_popup_title,
                originalError: localError
            )))
            return false
        }
        
        return true
    }
}

extension NSError {
    
    class func asProtonAddrRequiredError() -> Error {
        return NSError.init(domain: "protoncore-login",
                            code: -100,
                            localizedDescription: CoreString._ls_external_accounts_not_supported_popup_local_desc)
    }
}
