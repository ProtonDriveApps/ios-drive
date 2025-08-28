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

public enum PreviouslyLoggedInUser {
    case sameUser
    case differentUser
    case missingInfo
}

// Compares stored hashes to determine if the previous user is the same as the currently logged in
public protocol PreviouslyLoggedInUserRepositoryProtocol {
    func getPreviousUser() throws -> PreviouslyLoggedInUser
    func storeCurrentUser() throws
}

final class PreviouslyLoggedInUserRepository: PreviouslyLoggedInUserRepositoryProtocol {
    private let currentHashRepository: CurrentUserHashRepositoryProtocol
    private let storedHashRepository: StoredUserHashRepository

    init(currentHashRepository: CurrentUserHashRepositoryProtocol, storedHashRepository: StoredUserHashRepository) {
        self.currentHashRepository = currentHashRepository
        self.storedHashRepository = storedHashRepository
    }

    func getPreviousUser() throws -> PreviouslyLoggedInUser {
        let currentHash = try currentHashRepository.loadHash()

        guard let storedHash = try? storedHashRepository.loadHash() else {
            // Happens when upgrading app from version 1.45.0 or new install 
            return .missingInfo
        }

        if currentHash == storedHash {
            return .sameUser
        } else {
            return .differentUser
        }
    }

    func storeCurrentUser() throws {
        let currentHash = try currentHashRepository.loadHash()
        try storedHashRepository.store(hash: currentHash)
    }
}
