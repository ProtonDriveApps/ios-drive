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

protocol CurrentUserHashRepositoryProtocol {
    func loadHash() throws -> String
}

enum CurrentUserHashRepositoryError: Error {
    case missingUserId
}

final class CurrentUserHashRepository: CurrentUserHashRepositoryProtocol {
    private let sessionVault: SessionVault

    init(sessionVault: SessionVault) {
        self.sessionVault = sessionVault
    }

    func loadHash() throws -> String {
        guard let userId = sessionVault.userInfo?.ID else {
            throw CurrentUserHashRepositoryError.missingUserId
        }
        // Get userID hashed by itself. Use the id as key just for obscuring purposes.
        return try Encryptor.hmac(filename: userId, parentHashKey: userId)
    }
}
