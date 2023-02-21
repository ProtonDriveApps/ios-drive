//
//  DictionaryExtension.swift
//  ProtonCore-Utilities - Created on 7/2/15.
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

extension Dictionary where Key == String, Value == Any {
    
    /**
     base class for convert anyobject to a json string

     :param: value         AnyObject input value
     :param: prettyPrinted Bool is need pretty format

     :returns: String value
     */
    public func json(prettyPrinted: Bool = false) -> String {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? .prettyPrinted : JSONSerialization.WritingOptions()
        let anyObject: Any = self
        if JSONSerialization.isValidJSONObject(anyObject) {
            do {
                let data = try JSONSerialization.data(withJSONObject: anyObject, options: options)
                if let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    return string as String
                }
            } catch {
                PMLog.debug("\(error)")
            }
        }
        return ""
    }

}

extension Array where Iterator.Element == [String: Any]  {
    /**
     base class for convert anyobject to a json string

     :param: value         AnyObject input value
     :param: prettyPrinted Bool is need pretty format

     :returns: String value
     */
    public func json(prettyPrinted: Bool = false) -> String {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? .prettyPrinted : JSONSerialization.WritingOptions()
        let anyObject: Any = self
        if JSONSerialization.isValidJSONObject(anyObject) {
            do {
                let data = try JSONSerialization.data(withJSONObject: anyObject, options: options)
                if let string = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    return string as String
                }
            } catch _ as NSError {

            }
        }
        return ""
    }

}
