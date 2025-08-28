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

struct GroupLabelResponse: Codable {
    let code: Int
    let labels: [ContactGroup]
    
    enum CodingKeys: String, CodingKey {
        case code = "Code", labels = "Labels"
    }
    
    init(code: Int, labels: [ContactGroup]) {
        self.code = code
        self.labels = labels
    }
}

public struct ContactGroup: Codable {
    public let id: String
    public let name: String
    public let order: Int
    /// HEX color code, e.g. #3CBB3A
    public let color: String
    public private(set) var contacts: [Contact] = []
    
    enum CodingKeys: String, CodingKey {
        case id = "ID", name = "Name", order = "Order", color = "Color"
    }
    
    public init(id: String, name: String, order: Int, color: String) {
        self.id = id
        self.name = name
        self.order = order
        self.color = color
    }

    public mutating func append(contentsOf contacts: [Contact]) {
        self.contacts.append(contentsOf: contacts)
    }
    
    mutating func delete(contactID: String) {
        contacts.removeAll(where: { $0.id == contactID })
    }
    
    mutating func updateOrInsert(contact: Contact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
        } else {
            contacts.append(contact)
        }
    }
}
