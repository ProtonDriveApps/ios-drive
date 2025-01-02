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
import PMEventsManager

public protocol ContactUpdateDelegate: AnyObject {
    func update(contact: ContactEvent.ContactData)
    func delete(contactID: String)
    func create(contact: ContactEvent.ContactData)
    func delete(groupID: String)
    func create(contactGroup: LabelEvent.Label)
    func update(contactGroup: LabelEvent.Label)
}

protocol ContactStorage {
    var delegate: ContactUpdateDelegate? { get set }

    func update(contact: ContactEvent.ContactData)
    func delete(contactID: String)
    func create(contact: ContactEvent.ContactData)
    
    func delete(groupID: String)
    func create(contactGroup: LabelEvent.Label)
    func update(contactGroup: LabelEvent.Label)
}

// Adapter between core event loop and PDContacts
public final class ContactAdapter: ContactStorage {
    public weak var delegate: ContactUpdateDelegate?
    
    func create(contact: ContactEvent.ContactData) {
        delegate?.create(contact: contact)
    }
    
    func delete(contactID: String) {
        delegate?.delete(contactID: contactID)
    }
    
    func update(contact: ContactEvent.ContactData) {
        delegate?.update(contact: contact)
    }
    
    func delete(groupID: String) {
        delegate?.delete(groupID: groupID)
    }
    
    func create(contactGroup: LabelEvent.Label) {
        delegate?.create(contactGroup: contactGroup)
    }
    
    func update(contactGroup: LabelEvent.Label) {
        delegate?.update(contactGroup: contactGroup)
    }
}
