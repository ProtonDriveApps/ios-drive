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
import PDLocalization
import ProtonCoreUIFoundations

protocol ContactsQuerier {
    func execute(
        with keyword: String,
        excludedContactIDs: [String],
        invitedEmails: Set<String>
    ) async -> [ContactQueryResult]
}

final class ContactsQueryInteractor: ContactsQuerier {
    private let contactsController: ContactsControllerProtocol
    
    init(contactsController: ContactsControllerProtocol) {
        self.contactsController = contactsController
    }
    
    func execute(
        with keyword: String,
        excludedContactIDs: [String],
        invitedEmails: Set<String>
    ) async -> [ContactQueryResult] {
        do {
           let integralContacts = try await contactsController.fetchContacts()
            let filteredContacts = query(
                contacts: integralContacts.basicContacts,
                keyword: keyword,
                excludedIDs: excludedContactIDs,
                invitedEmails: invitedEmails
            )
            let filteredGroups = query(
                contactGroups: integralContacts.contactGroups,
                by: keyword,
                excludedIDs: excludedContactIDs
            )
            return filteredContacts + filteredGroups
        } catch {
            return []
        }
    }
    
    /// Search for contacts using the specified keyword, ignoring case sensitivity.
    /// - Parameters:
    ///   - keyword: Keyword used for searching in the name or email fields.
    ///   - excludedIDs: Excluded ID array, format is `{ContactID}@{email.hashValue}`
    /// - Returns: Matched contacts
    private func query(
        contacts: [BasicContact],
        keyword: String,
        excludedIDs: [String],
        invitedEmails: Set<String>
    ) -> [ContactQueryResult] {
        let keyword = keyword.lowercased()
        return contacts
            .filter { contact in
                if excludedIDs.contains(contact.id) || invitedEmails.contains(contact.email) { return false }
                if contact.name.lowercased().contains(keyword) { return true }
                return contact.email.contains(keyword)
            }
            .sorted { contactA, contactB in
                if contactA.lastUsedTime >= contactB.lastUsedTime {
                    return true
                } else {
                    return contactA.name >= contactB.name
                }
            }
            .map { contact in
                let name = contact.name.asAttributedString(keywords: [keyword], highlightColor: ColorProvider.TextAccent)
                let info = contact.email.asAttributedString(keywords: [keyword], highlightColor: ColorProvider.TextAccent)
                return ContactQueryResult(
                    id: contact.id,
                    attributedName: name,
                    attributedInfo: info,
                    name: contact.name,
                    mails: [contact.email]
                )
            }
    }
    
    /// Search for contact groups using the specified keyword, ignoring case sensitivity.
    /// - Parameters:
    ///   - keyword: Keyword used for searching in the group name fields.
    ///   - excludedIDs: Excluded group id array
    /// - Returns: Matched contacts
    private func query(
        contactGroups: [ContactGroup],
        by keyword: String,
        excludedIDs: [String]
    ) -> [ContactQueryResult] {
        let keyword = keyword.lowercased()
        return contactGroups
            .filter({ group in
                if excludedIDs.contains(group.id) { return false }
                return group.name.lowercased().contains(keyword)
            })
            .compactMap { group in
                let mails = getMails(from: group)
                if mails.isEmpty { return nil }
                let name = group.name.asAttributedString(keywords: [keyword], highlightColor: ColorProvider.TextAccent)
                let info = Localization.sharing_members(num: group.contacts.count)
                return ContactQueryResult(
                    id: group.id,
                    attributedName: name,
                    attributedInfo: NSAttributedString(string: info),
                    name: group.name,
                    isGroup: true,
                    mails: mails
                )
            }
    }
    
    private func getMails(from group: ContactGroup) -> [String] {
        var mails: [String] = []
        for contact in group.contacts {
            guard
                let mail = contact.contactEmails.max(by: { mailA, mailB in
                    mailA.lastUsedTime > mailB.lastUsedTime
                })?.email
            else { continue }
            mails.append(mail)
        }
        return mails
    }
}
