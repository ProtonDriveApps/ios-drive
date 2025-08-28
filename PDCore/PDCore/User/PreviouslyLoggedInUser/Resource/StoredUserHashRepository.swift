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

protocol StoredUserHashRepository {
    func store(hash: String) throws
    func loadHash() throws -> String
}

enum KeychainUserHashRepositoryError: Error {
    case missingData
    case invalidData
}

final class KeychainUserHashRepository: StoredUserHashRepository {
    private let keychain: DriveKeychainProtocol
    private static let userHashIdentifier = "userHashIdentifier"

    init(keychain: DriveKeychainProtocol) {
        self.keychain = keychain
    }

    func store(hash: String) throws {
        let hashData = Data(hash.utf8)
        try keychain.setOrError(hashData, forKey: KeychainUserHashRepository.userHashIdentifier, attributes: nil)
    }

    func loadHash() throws -> String {
        guard let data = try keychain.dataOrError(forKey: KeychainUserHashRepository.userHashIdentifier, attributes: nil) else {
            throw KeychainUserHashRepositoryError.missingData
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainUserHashRepositoryError.invalidData
        }
        return string
    }
}
