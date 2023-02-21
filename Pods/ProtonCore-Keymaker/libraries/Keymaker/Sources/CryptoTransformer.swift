//
//  CryptoTransformer.swift
//  ProtonCore-ProtonCore-Keymaker - Created on 15/11/2018.
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

public class StringCryptoTransformer: CryptoTransformer {
    // String -> Data
    override public func transformedValue(_ value: Any?) -> Any? {
        guard let string = value as? String else {
            return nil
        }
        
        do {
            let locked = try Locked<String>(clearValue: string, with: self.key)
            let result = locked.encryptedValue as NSData
            return result
        } catch let error {
            assert(false, "Error while encrypting value: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Data -> String
    override public func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            return nil
        }
        
        let locked = Locked<String>(encryptedValue: data)
        do {
            let string = try locked.unlock(with: self.key)
            return string
        } catch let error {
            assert(false, "Error while decrypting value: \(error.localizedDescription)")
        }
        
        return nil
    }
}

public class CryptoTransformer: ValueTransformer {
    fileprivate var key: MainKey
    public init(key: MainKey) {
        self.key = key
    }
    
    override public class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override public class func allowsReverseTransformation() -> Bool {
        return true
    }
}
