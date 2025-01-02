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

struct EmailResponse: Codable {
    let code: Int
    let contactEmails: [ContactEmail]
    let total: Int
    
    enum CodingKeys: String, CodingKey {
        case code = "Code", contactEmails = "ContactEmails", total = "Total"
    }
    
    init(code: Int, contactEmails: [ContactEmail], total: Int) {
        self.code = code
        self.contactEmails = contactEmails
        self.total = total
    }
}

public struct ContactEmail: Codable, Equatable {
    public let contactID: String
    public let email: String
    /// false if contact contains custom sending preferences or keys
    /// true otherwise
    public let defaults: Bool
    public let order: Int
    /// Tells whether this is an official Proton address
    public let isProton: Bool
    /// 2001-01-01 00:00:00 +0000 aka timeIntervalSinceReferenceDate : 0.0
    /// This indicates that the address is never utilized.
    public let lastUsedTime: Date
    
    enum CodingKeys: String, CodingKey {
        case contactID = "ContactID"
        case email = "Email"
        case defaults = "Defaults"
        case order = "Order"
        case isProton = "IsProton"
        case lastUsedTime = "LastUsedTime"
    }
    
    public init(contactID: String, email: String, defaults: Bool, order: Int, isProton: Bool, lastUsedTime: Date) {
        self.contactID = contactID
        self.email = email
        self.defaults = defaults
        self.order = order
        self.isProton = isProton
        self.lastUsedTime = lastUsedTime
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.contactID = try container.decode(String.self, forKey: .contactID)
        self.email = try container.decode(String.self, forKey: .email)
        let defaultsValue = try container.decode(Int.self, forKey: .defaults)
        self.defaults = defaultsValue == 1 ? true : false
        self.order = try container.decode(Int.self, forKey: .order)
        let isProtonValue = try container.decode(Int.self, forKey: .isProton)
        self.isProton = isProtonValue == 1 ? true : false
        self.lastUsedTime = try container.decode(Date.self, forKey: .lastUsedTime)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contactID, forKey: .contactID)
        try container.encode(email, forKey: .email)
        try container.encode(defaults ? 1 : 0, forKey: .defaults)
        try container.encode(order, forKey: .order)
        try container.encode(isProton ? 1 : 0, forKey: .isProton)
        try container.encode(lastUsedTime, forKey: .lastUsedTime)
    }
}
