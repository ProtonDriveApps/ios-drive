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

/// Basic contact information with essential details.
public struct BasicContact {
    let id: String
    let name: String
    let email: String
    let lastUsedTime: Date
    
    init(
        contactID: String,
        name: String,
        email: String,
        lastUsedTime: Date
    ) {
        self.id = "\(contactID)#\(email)"
        self.name = name
        self.email = email
        self.lastUsedTime = lastUsedTime
    }
}

public struct IntegralContacts {
    let basicContacts: [BasicContact]
    let contactGroups: [ContactGroup]

    public init(basicContacts: [BasicContact], contactGroups: [ContactGroup]) {
        self.basicContacts = basicContacts
        self.contactGroups = contactGroups
    }
}
