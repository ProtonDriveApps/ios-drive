//
//  Address+NSCoding.swift
//  ProtonCore-DataModel - Created on 4/19/21.
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

// MARK: - TODO:: we'd better move to Codable or at least NSSecureCoding when will happen to refactor this part of app from Anatoly
extension Address: NSCoding {
    public func archive() -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
    
    public static func unarchive(_ data: Data?) -> Address? {
        guard let data = data else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(with: data) as? Address
    }
    
    // the keys all messed up but it works ( don't copy paste there looks really bad)
    fileprivate struct CoderKey {
        static let addressID    = "displayName"
        static let email        = "maxSpace"
        static let order        = "notificationEmail"
        static let receive      = "privateKey"
        static let mailbox      = "publicKey"
        static let displayName = "signature"
        static let signature    = "usedSpace"
        static let keys         = "userKeys"
        
        static let addressStatus = "addressStatus"
        static let addressType   = "addressType"
        static let addressSend   = "addressSendStatus"
        
        static let domainID = "Address.DomainID"
        static let hasKeys  = "Address.HasKeys"
    }
    
    public convenience init(coder aDecoder: NSCoder) {
        self.init(addressID: aDecoder.string(forKey: CoderKey.addressID) ?? "",
                  domainID: aDecoder.string(forKey: CoderKey.domainID) ?? "",
                  email: aDecoder.string(forKey: CoderKey.email) ?? "",
                  send: Address.AddressSendReceive(rawValue: aDecoder.decodeInteger(forKey: CoderKey.addressSend)) ?? .inactive,
                  receive: Address.AddressSendReceive(rawValue: aDecoder.decodeInteger(forKey: CoderKey.receive)) ?? .inactive,
                  status: Address.AddressStatus(rawValue: aDecoder.decodeInteger(forKey: CoderKey.addressStatus)) ?? .disabled,
                  type: AddressType(rawValue: aDecoder.decodeInteger(forKey: CoderKey.addressType)) ?? .protonDomain,
                  order: aDecoder.decodeInteger(forKey: CoderKey.order),
                  displayName: aDecoder.string(forKey: CoderKey.displayName) ?? "",
                  signature: aDecoder.string(forKey: CoderKey.signature) ?? "",
                  hasKeys: aDecoder.decodeInteger(forKey: CoderKey.hasKeys),
                  keys: aDecoder.decodeObject(forKey: CoderKey.keys) as? [Key] ?? [])
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(addressID, forKey: CoderKey.addressID)
        aCoder.encode(email, forKey: CoderKey.email)
        aCoder.encode(order, forKey: CoderKey.order)
        aCoder.encode(receive.rawValue, forKey: CoderKey.receive)
        aCoder.encode(displayName, forKey: CoderKey.displayName)
        aCoder.encode(signature, forKey: CoderKey.signature)
        aCoder.encode(keys, forKey: CoderKey.keys)

        aCoder.encode(status.rawValue, forKey: CoderKey.addressStatus)
        aCoder.encode(type.rawValue, forKey: CoderKey.addressType)

        aCoder.encode(send.rawValue, forKey: CoderKey.addressSend)

        aCoder.encode(domainID, forKey: CoderKey.domainID)
        aCoder.encode(hasKeys, forKey: CoderKey.hasKeys)
    }
}
