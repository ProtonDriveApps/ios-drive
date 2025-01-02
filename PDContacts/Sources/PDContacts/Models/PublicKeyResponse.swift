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

public struct PublicKeyResponse: Decodable {
    public let code: Int
    public let isProton: Bool
    /// True when domain has valid proton MX
    public let protonMX: Bool
    /// List of warnings to show to the user related to phishing and message routing
    public let warnings: [String]
    public let address: Address
    public let unverified: Address?
    
    enum CodingKeys: String, CodingKey {
        case Code, IsProton, ProtonMX, Warnings, Address, Unverified
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decode(Int.self, forKey: .Code)
        let isProtonValue = try container.decode(Int.self, forKey: .IsProton)
        self.isProton = isProtonValue == 1 ? true : false
        self.protonMX = try container.decode(Bool.self, forKey: .ProtonMX)
        self.warnings = try container.decode([String].self, forKey: .Warnings)
        self.address = try container.decode(Address.self, forKey: .Address)
        self.unverified = try container.decodeIfPresent(Address.self, forKey: .Unverified)
    }
    
    public init(
        code: Int,
        isProton: Bool,
        protonMX: Bool,
        warnings: [String],
        address: Address,
        unverified: Address? = nil
    ) {
        self.code = code
        self.isProton = isProton
        self.protonMX = protonMX
        self.warnings = warnings
        self.address = address
        self.unverified = unverified
    }
}

public struct Address: Decodable {
    public let keys: [Key]
    // SignedKeyList is not implemented
    
    enum CodingKeys: String, CodingKey {
        case keys = "Keys"
    }
    
    public init(keys: [Key]) {
        self.keys = keys
    }
}

public struct Key: Decodable {
    /// Key usage flags
    public let flags: Flags
    /// Armored OpenPGP public key
    public let publicKey: String
    /// Always (0) internal for verified keys
    public let source: Int
    
    public struct Flags: OptionSet, Decodable {
        public let rawValue: Int

        /// 2^0 = 1 means the key is not compromised (i.e. if we can trust signatures coming from it)
        public static let notCompromised = Self(rawValue: 1 << 0)

        /// 2^1 = 2 means the key is still in use (i.e. not obsolete, we can encrypt messages to it)
        public static let notObsolete = Self(rawValue: 2 << 0)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case flags = "Flags", publicKey = "PublicKey", source = "Source"
    }
    
    public init(flags: Flags, publicKey: String, source: Int) {
        self.flags = flags
        self.publicKey = publicKey
        self.source = source
    }
}

struct KeyQuery: Hashable {
    let email: String
    let internalOnly: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(email)
        hasher.combine(internalOnly)
    }
}
