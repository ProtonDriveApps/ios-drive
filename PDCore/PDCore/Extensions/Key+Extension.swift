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

import ProtonCoreDataModel

extension Key {
    /// This method redirects to method with similar signature in `ProtonCoreKeyManager` and should be used in files that import both `ProtonCoreCrypto` and `ProtonCoreKeyManager`, both of which contain extension of `Key` containting this method - compiler gets confused.
    /// This file does not import these frameworks which allows compiler to see only one implementation fetched via `ProtonCoreDataModel` dependency.
    func _passphrase(userKeys: [Key], mailboxPassphrase: String) throws -> String {
        try passphrase(userKeys: userKeys, mailboxPassphrase: mailboxPassphrase)
    }
}
