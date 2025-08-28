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

struct ContactResponse: Codable {
    let code: Int
    let contacts: [Contact]
    let total: Int
    
    enum CodingKeys: String, CodingKey {
        case code = "Code", contacts = "Contacts", total = "Total"
    }
    
    init(code: Int, contacts: [Contact], total: Int) {
        self.code = code
        self.contacts = contacts
        self.total = total
    }
}

public struct Contact: Codable, Equatable {
    /// Encrypted contact ID
    public let id: String
    public let name: String
    public let uid: String
    public let createTime: Date
    public let modifyTime: Date
    public private(set) var labelIDs: [String]
    public private(set) var contactEmails: [ContactEmail] = []
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case name = "Name"
        case uid = "UID"
        case createTime = "CreateTime"
        case modifyTime = "ModifyTime"
        case labelIDs = "LabelIDs"
    }
    
    public init(
        id: String,
        name: String,
        uid: String,
        createTime: Date,
        modifyTime: Date,
        labelIDs: [String]
    ) {
        self.id = id
        self.name = name
        self.uid = uid
        self.createTime = createTime
        self.modifyTime = modifyTime
        self.labelIDs = labelIDs
    }
    
    public mutating func append(contactEmail: ContactEmail) {
        if contactEmails.map(\.email).contains(contactEmail.email) { return }
        contactEmails.append(contactEmail)
        contactEmails.sort(by: { $0.lastUsedTime >= $1.lastUsedTime })
    }
    
    mutating func add(labelID: String) {
        labelIDs.append(labelID)
    }
    
    mutating func remove(labelID: String) {
        labelIDs.removeAll(where: { $0 == labelID })
    }
}
