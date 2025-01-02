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

import Combine
import Foundation
import ProtonCoreNetworking
import ProtonCoreServices

public protocol ContactsManagerProtocol {
    var contactUpdatedNotifier: AnyPublisher<Void, Never> { get }

    func fetchIntegralContacts() async throws -> ([Contact], [ContactGroup])
    func fetchUserContacts() async throws -> [Contact]
    func fetchUserContactGroups() async throws -> [ContactGroup]
    func fetchActivePublicKeys(email: String, internalOnly: Bool) async throws -> PublicKeyResponse
    func create(contact: Contact, with emails: [ContactEmail])
    func delete(contactID: String)
    func update(contact: Contact, with emails: [ContactEmail])
    func delete(groupID: String)
    func create(group: ContactGroup)
    func update(group: ContactGroup)
}

public final class ContactsManager: ContactsManagerProtocol {
    
    private let jsonDecoder: JSONDecoder = JSONDecoder()
    private let service: APIService
    private var log: ((String) -> Void)?
    private var error: ((String) -> Void)?
    private var contacts: [Contact] = []
    private var contactGroups: [ContactGroup] = []
    private var isContactInitialized = false
    private var isContactGroupInitialized = false
    private var keyCache: [KeyQuery: PublicKeyResponse] = [:]
    private let contactUpdateSubject = PassthroughSubject<Void, Never>()
    public var contactUpdatedNotifier: AnyPublisher<Void, Never> { contactUpdateSubject.eraseToAnyPublisher() }
    
    public init(service: APIService, log: ((String) -> Void)?, error: ((String) -> Void)?) {
        self.service = service
        self.log = log
        self.error = error
    }
    
    /// Retrieve user integral contacts:
    /// if they are available in the in-memory cache, return them from there;
    /// otherwise, query the backend.
    /// - Returns: (user contacts, user contact groups)
    public func fetchIntegralContacts() async throws -> ([Contact], [ContactGroup]) {
        let contacts = try await fetchUserContacts()
        let contactGroups = try await fetchUserContactGroups()
        return (contacts, contactGroups)
    }
    
    /// Retrieve user contacts:
    /// if they are available in the in-memory cache, return them from there;
    /// otherwise, query the backend.
    /// - Returns: user contacts
    public func fetchUserContacts() async throws -> [Contact] {
        if isContactInitialized { return contacts }
        
        async let contactsAsync = fetchAllContacts()
        async let emailsAsync = fetchAllEmails()
        let (contactsRes, emailsRes) = await (contactsAsync, emailsAsync)
        switch (contactsRes, emailsRes) {
        case (.success(let contacts), .success(let emails)):
            self.contacts = map(contacts: contacts, contactEmails: emails)
            isContactInitialized = true
            log?("Successfully retrieved user contacts; total number of contacts: \(contacts.count)")
            return self.contacts
        case (.failure(let error), _):
            throw error
        case (_, .failure(let error)):
            throw error
        }
    }
    
    /// Retrieve user contact group:
    /// if they are available in the in-memory cache, return them from there;
    /// otherwise, query the backend.
    /// - Returns: user contacts
    public func fetchUserContactGroups() async throws -> [ContactGroup] {
        defer {
            log?("Successfully retrieved user contact groups; total number of groups: \(contactGroups.count)")
        }
        if isContactGroupInitialized { return contactGroups }
        let contactGroups = try await fetchContactGroupLabel().labels
        let contacts = try await fetchUserContacts()
        self.contactGroups = map(contactGroups: contactGroups, contacts: contacts)
        isContactGroupInitialized = true
        return self.contactGroups
    }
    
    /// - Parameters:
    ///   - email: Mail address, e.g. tester@pm.me
    ///   - internalOnly: If true, it will not perform any external lookup, and only provide information from the Proton DB
    public func fetchActivePublicKeys(email: String, internalOnly: Bool = true) async throws -> PublicKeyResponse {
        let query = KeyQuery(email: email, internalOnly: internalOnly)
        if let cache = keyCache[query] {
            return cache
        }
        
        let request = PublicKeyRequest(email: email, internalOnly: internalOnly)
        log(request: request)
        do {
            let response = try await service.perform(request: request)
            let jsonDict = response.1
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
            let res = try jsonDecoder.decode(PublicKeyResponse.self, from: jsonData)
            keyCache[query] = res
            return res
        } catch {
            log(failedRequest: request, error: error)
            throw error
        }
    }
    
    public func delete(contactID: String) {
        contacts.removeAll(where: { $0.id == contactID })
        for var group in contactGroups {
            group.delete(contactID: contactID)
        }
        contactUpdateSubject.send()
    }
    
    public func create(contact: Contact, with emails: [ContactEmail]) {
        guard !contacts.map(\.id).contains(contact.id) else { return }
        var contact = contact
        for email in emails {
            contact.append(contactEmail: email)
        }
        contacts.append(contact)
        contactUpdateSubject.send()
    }
    
    public func update(contact: Contact, with emails: [ContactEmail]) {
        var contact = contact
        for email in emails {
            contact.append(contactEmail: email)
        }
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = contact
        } else {
            contacts.append(contact)
        }
        for index in contactGroups.indices {
            if contact.labelIDs.contains(contactGroups[index].id) {
                contactGroups[index].updateOrInsert(contact: contact)
            } else {
                contactGroups[index].delete(contactID: contact.id)
            }
        }
        contactUpdateSubject.send()
    }
    
    public func delete(groupID: String) {
        contactGroups.removeAll(where: { $0.id == groupID })
        for index in contacts.indices {
            contacts[index].remove(labelID: groupID)
        }
        contactUpdateSubject.send()
    }
    
    public func create(group: ContactGroup) {
        guard !contactGroups.map(\.id).contains(group.id) else { return }
        contactGroups.append(group)
        contactUpdateSubject.send()
    }
    
    public func update(group: ContactGroup) {
        if let existingGroup = contactGroups.first(where: { $0.id == group.id }) {
            let contacts = existingGroup.contacts
            var group = group
            group.append(contentsOf: contacts)
            guard let index = contactGroups.firstIndex(where: { $0.id == group.id }) else { return }
            contactGroups[index] = group
        } else {
            create(group: group)
        }
        contactUpdateSubject.send()
    }
}

// MARK: - Fetch data
extension ContactsManager {
    private func fetchAllContacts() async -> Result<[Contact], Error> {
        var contacts: [Contact] = []
        var page = 0
        do {
            while true {
                let response = try await fetchContacts(page: page)
                contacts.append(contentsOf: response.contacts)
                if contacts.count == response.total {
                    break
                } else {
                    page += 1
                }
            }
        } catch {
            return .failure(error)
        }
        return .success(contacts)
    }
    
    private func fetchContacts(page: Int) async throws -> ContactResponse {
        let request = ContactRequest(page: page)
        return try await perform(request: request)
    }
    
    private func fetchAllEmails() async -> Result<[ContactEmail], Error> {
        var emails: [ContactEmail] = []
        var page = 0
        do {
            while true {
                let response = try await fetchEmails(page: page)
                emails.append(contentsOf: response.contactEmails)
                if emails.count == response.total {
                    break
                } else {
                    page += 1
                }
            }
        } catch {
            return .failure(error)
        }
        return .success(emails)
    }
    
    private func fetchEmails(page: Int) async throws -> EmailResponse {
        let request = EmailRequest(page: page)
        return try await perform(request: request)
    }
    
    private func fetchContactGroupLabel() async throws -> GroupLabelResponse {
        let request = GroupLabelRequest()
        return try await perform(request: request)
    }
    
    private func perform<T: Decodable>(request: Request) async throws -> T {
        log(request: request)
        do {
            let jsonDict = try await service.perform(request: request).1
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
            let res = try jsonDecoder.decode(T.self, from: jsonData)
            return res
        } catch {
            log(failedRequest: request, error: error)
            throw error
        }
    }
    
    private func map(contacts: [Contact], contactEmails: [ContactEmail]) -> [Contact] {
        var contacts = contacts
        for email in contactEmails {
            guard let contactIdx = contacts.firstIndex(where: { $0.id == email.contactID }) else { continue }
            contacts[contactIdx].append(contactEmail: email)
        }
        return contacts
    }
    
    private func map(contactGroups: [ContactGroup], contacts: [Contact]) -> [ContactGroup] {
        var contactGroups = contactGroups
        for idx in 0..<contactGroups.count {
            let id = contactGroups[idx].id
            let contact = contacts.filter { $0.labelIDs.contains(id) }
            contactGroups[idx].append(contentsOf: contact)
        }
        return contactGroups
    }
}

// MARK: - Log
extension ContactsManager {
    private func log(request: Request) {
        let logStr = "REQUEST: 🌐🌐🌐🌐 \(request.method.rawValue) - \(request.self)"
        log?(logStr)
    }
    
    private func log(failedRequest: Request, error: Error) {
        let responseHeader = "RESPONSE: 📩📩📩📩 \(failedRequest.method.rawValue) - \(failedRequest.self)"
        let desc = """
        \(responseHeader)
        ++++++++++++++++++++++++++++++++
        |- Error ❌: \(error.localizedDescription)
        --------------------------------
        """
        
        self.error?(desc)
    }
}
