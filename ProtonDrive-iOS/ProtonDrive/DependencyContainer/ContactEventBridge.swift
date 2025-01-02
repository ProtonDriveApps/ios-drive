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
import PDContacts
import PDCore
import PMEventsManager

final class ContactEventBridge: ContactUpdateDelegate {
    private let contactsManager: ContactsManagerProtocol
    
    init(contactsManager: ContactsManagerProtocol) {
        self.contactsManager = contactsManager
    }
    
    private func transfer(
        data: ContactEvent.ContactData
    ) -> (contact: PDContacts.Contact, emails: [PDContacts.ContactEmail]) {
        let contact = PDContacts.Contact(
            id: data.contactID,
            name: data.name,
            uid: data.uid,
            createTime: data.modifyTime,
            modifyTime: data.modifyTime,
            labelIDs: data.labelIDs
        )
        var emails: [PDContacts.ContactEmail] = []
        for eventMail in data.contactEmails {
            let email = PDContacts.ContactEmail(
                contactID: eventMail.contactID,
                email: eventMail.email,
                defaults: eventMail.defaults,
                order: eventMail.order,
                isProton: eventMail.isProton,
                lastUsedTime: eventMail.lastUsedTime
            )
            emails.append(email)
        }
        return (contact, emails)
    }
    
    private func transfer(data: LabelEvent.Label) -> ContactGroup {
        .init(id: data.id, name: data.name, order: data.order, color: data.color)
    }
    
    func update(contact: ContactEvent.ContactData) {
        let (contact, emails) = transfer(data: contact)
        contactsManager.update(contact: contact, with: emails)
    }
    
    func delete(contactID: String) {
        contactsManager.delete(contactID: contactID)
    }
    
    func create(contact: ContactEvent.ContactData) {
        let (contact, emails) = transfer(data: contact)
        contactsManager.create(contact: contact, with: emails)
    }
    
    func delete(groupID: String) {
        contactsManager.delete(groupID: groupID)
    }
    
    func create(contactGroup: LabelEvent.Label) {
        let group = transfer(data: contactGroup)
        contactsManager.create(group: group)
    }
    
    func update(contactGroup: LabelEvent.Label) {
        let group = transfer(data: contactGroup)
        contactsManager.update(group: group)
    }
}
