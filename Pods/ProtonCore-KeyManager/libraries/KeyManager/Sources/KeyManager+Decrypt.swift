//
//  Key+Ext.swift
//  ProtonCore-KeyManager - Created on 4/19/21.
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
import GoLibs
import ProtonCore_DataModel

@available(*, deprecated, message: "Please use the non-optional variant")
public func decryptAttachment(dataPackage: Data,
                              keyPackage: Data,
                              addrKeys: [Key],
                              userBinKeys privateKeys: [Data],
                              passphrase: String) throws -> Data? {
    if addrKeys.isKeyV2 {
        return try dataPackage.decryptAttachment(keyPackage: keyPackage,
                                                 userKeys: privateKeys,
                                                 passphrase: passphrase,
                                                 keys: addrKeys)
    } else {
        return try dataPackage.decryptAttachment(dataPackage,
                                                 passphrase: passphrase,
                                                 privKeys: addrKeys.binPrivKeysArray)
    }
}

public func decryptAttachmentNonOptional(dataPackage: Data,
                                         keyPackage: Data,
                                         addrKeys: [Key],
                                         userBinKeys privateKeys: [Data],
                                         passphrase: String) throws -> Data {
    if addrKeys.isKeyV2 {
        return try dataPackage.decryptAttachmentNonOptional(keyPackage: keyPackage,
                                                            userKeys: privateKeys,
                                                            passphrase: passphrase,
                                                            keys: addrKeys)
    } else {
        return try dataPackage.decryptAttachmentNonOptional(dataPackage,
                                                            passphrase: passphrase,
                                                            privKeys: addrKeys.binPrivKeysArray)
    }
}
