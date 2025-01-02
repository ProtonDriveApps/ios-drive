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

public struct ContactEvent: Codable {
    public let contactID: String
    public let action: Action
    public let contact: ContactData?
    
    enum CodingKeys: String, CodingKey {
        case contactID = "ID"
        case action, contact
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.contactID = try container.decode(String.self, forKey: .contactID)
        self.action = try container.decode(Action.self, forKey: .action)
        self.contact = try container.decodeIfPresent(ContactEvent.ContactData.self, forKey: .contact)
    }
}

extension ContactEvent {
    public struct ContactData: Codable {
        public let contactID: String
        public let name: String
        public let uid: String
        public let modifyTime: Date
        public let contactEmails: [ContactsEmailData]
        public let labelIDs: [String]
        
        enum CodingKeys: String, CodingKey {
            case contactID = "ID"
            case uid = "UID"
            case name, modifyTime, contactEmails, labelIDs
        }
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ContactEvent.ContactData.CodingKeys> = try decoder.container(keyedBy: ContactEvent.ContactData.CodingKeys.self)
            self.contactID = try container.decode(String.self, forKey: ContactEvent.ContactData.CodingKeys.contactID)
            self.name = try container.decode(String.self, forKey: ContactEvent.ContactData.CodingKeys.name)
            self.uid = try container.decode(String.self, forKey: ContactEvent.ContactData.CodingKeys.uid)
            self.modifyTime = try container.decode(Date.self, forKey: ContactEvent.ContactData.CodingKeys.modifyTime)
            self.contactEmails = try container.decode([ContactEvent.ContactsEmailData].self, forKey: ContactEvent.ContactData.CodingKeys.contactEmails)
            self.labelIDs = try container.decode([String].self, forKey: ContactEvent.ContactData.CodingKeys.labelIDs)
        }
        
        public init(
            contactID: String,
            name: String,
            uid: String,
            modifyTime: Date,
            contactEmails: [ContactsEmailData],
            labelIDs: [String]
        ) {
            self.contactID = contactID
            self.name = name
            self.uid = uid
            self.modifyTime = modifyTime
            self.contactEmails = contactEmails
            self.labelIDs = labelIDs
        }
    }
    
    public struct ContactsEmailData: Codable {
        public let email: String
        public let isProton: Bool
        public let defaults: Bool
        public let lastUsedTime: Date
        public let contactID: String
        public let order: Int
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ContactEvent.ContactsEmailData.CodingKeys> = try decoder.container(keyedBy: ContactEvent.ContactsEmailData.CodingKeys.self)
            self.email = try container.decode(String.self, forKey: ContactEvent.ContactsEmailData.CodingKeys.email)
            let isProtonValue = try container.decode(Int.self, forKey: ContactEvent.ContactsEmailData.CodingKeys.isProton)
            self.isProton = isProtonValue == 0 ? false : true
            let defaultsValue = try container.decode(Int.self, forKey: ContactEvent.ContactsEmailData.CodingKeys.defaults)
            self.defaults = defaultsValue == 0 ? false : true
            self.lastUsedTime = try container.decode(Date.self, forKey: ContactEvent.ContactsEmailData.CodingKeys.lastUsedTime)
            self.contactID = try container.decode(String.self, forKey: ContactEvent.ContactsEmailData.CodingKeys.contactID)
            self.order = try container.decode(Int.self, forKey: ContactEvent.ContactsEmailData.CodingKeys.order)
        }
        
        public init(
        email: String,
        isProton: Bool,
        defaults: Bool,
        lastUsedTime: Date,
        contactID: String,
        order: Int
        ) {
            self.email = email
            self.isProton = isProton
            self.defaults = defaults
            self.lastUsedTime = lastUsedTime
            self.contactID = contactID
            self.order = order
        }
    }
}
