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

import Foundation

public extension Data {
    func hexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// Initializes Data from a hexadecimal string.
    /// Returns nil if the hex string is invalid (not multiple of 2 or contains invalid characters).
    init?(hex: String) {
        // Ensure the hex string has an even number of characters.
        guard hex.count.isMultiple(of: 2) else {
            return nil
        }
        
        // Convert the hex string into an array of characters.
        let characters = Array(hex)
        
        // Process the hex string two characters at a time and convert each pair to a byte.
        var bytes = [UInt8]()
        for index in stride(from: 0, to: characters.count, by: 2) {
            let hexPair = String(characters[index]) + String(characters[index + 1])
            guard let byte = UInt8(hexPair, radix: 16) else {
                return nil
            }
            bytes.append(byte)
        }
        
        // Initialize Data with the byte array.
        self.init(bytes)
    }

    func base64URLEncodedString() -> String {
        var result = self.base64EncodedString()
        result = result.replacingOccurrences(of: "+", with: "-")
        result = result.replacingOccurrences(of: "/", with: "_")
        result = result.replacingOccurrences(of: "=", with: "")
        return result
    }
}
