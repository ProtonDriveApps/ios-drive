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

import ProtonCoreAuthentication
import ProtonCoreDataModel
import ProtonCoreNetworking

public protocol AddressProvider {
    func fetchAddresses() async throws -> [Address]
}

// Adapter to use AddressManager asynchronously
extension AddressManager: AddressProvider {
    public func fetchAddresses() async throws -> [Address] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAddresses { result in
                switch result {
                case .success(let addresses):
                    continuation.resume(returning: addresses)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

public class AddressManager {
    public typealias Address = ProtonCoreDataModel.Address
    public typealias AddressKey = ProtonCoreDataModel.Key

    private var sessionVault: SessionVault
    private var authenticator: Authenticator

    init(authenticator: Authenticator, sessionVault: SessionVault) {
        self.authenticator = authenticator
        self.sessionVault = sessionVault
    }

    enum Errors: Error {
        case noClientCredential, invalidMailboxPassword, noPrimaryAddress
    }

    func signOut() {
        // nothig so far
    }

    func fetchAddresses(_ handler: @escaping (Result<[Address], Error>) -> Void) {
        // 1 - get Addresses
        self.authenticator.getAddresses { resultAddresses in
            switch resultAddresses {
            case let .success(addresses):
                // 2 - get User
                self.fetchUserInfo { resultUserInfo in
                    switch resultUserInfo {
                    case let .success(user):
                        // 3 - validate MailboxPassword, either for AddressKey or for UserKey
                        guard self.sessionVault.validateMailboxPassword(addresses, user.keys) else {
                            return handler(.failure(Errors.invalidMailboxPassword))
                        }
                        self.sessionVault.storeUser(user)
                        self.sessionVault.storeAddresses(addresses)
                        handler(.success(addresses))

                    case let .failure(error):
                        handler(.failure(error))
                    }
                }
            case let .failure(error):
                handler(.failure(error))
            }
        }
    }

    func fetchAddressesAsync() async throws -> [Address] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAddresses { result in
                switch result {
                case .success(let addresses):
                    continuation.resume(returning: addresses)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchUserInfo(_ handler: @escaping (Result<User, Error>) -> Void) {
        guard self.sessionVault.sessionCredential != nil else {
            return handler(.failure(Errors.noClientCredential))
        }

        self.authenticator.getUserInfo { result in
            switch result {
            case .success(let user):
                handler(.success(user))
            case .failure(let error):
                handler(.failure(error))
            }
        }
    }
}
