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
    private struct ContactCacheState {
        var contacts: [Contact] = []
        var contactGroups: [ContactGroup] = []
        var isContactInitialized = false
        var isContactGroupInitialized = false
    }
    
    private let jsonDecoder: JSONDecoder = JSONDecoder()
    private let service: APIService
    private var log: ((String) -> Void)?
    private var error: ((String) -> Void)?
    private let contactCacheState = Atomic(ContactCacheState())
    private var keyCache: Atomic<[KeyQuery: PublicKeyResponse]> = .init([:])
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
        if let cachedContacts = contactCacheState.transform({ $0.isContactInitialized ? $0.contacts : nil }) {
            log?("Successfully retrieved \(cachedContacts.count) user contacts from cache")
            return cachedContacts
        }
        
        async let contactsAsync = fetchAllContacts()
        async let emailsAsync = fetchAllEmails()
        let (contactsRes, emailsRes) = await (contactsAsync, emailsAsync)
        switch (contactsRes, emailsRes) {
        case (.success(let contacts), .success(let emails)):
            let mappedContacts = map(contacts: contacts, contactEmails: emails)
            contactCacheState.mutate { state in
                state.contacts = mappedContacts
                state.isContactInitialized = true
            }
            log?("Successfully retrieved \(contacts.count) user contacts")
            return mappedContacts
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
        if let cachedGroups = contactCacheState.transform({ $0.isContactGroupInitialized ? $0.contactGroups : nil }) {
            log?("Successfully retrieved \(cachedGroups.count) contact groups from cache")
            return cachedGroups
        }
        let fetchedContactGroups = try await fetchContactGroupLabel().labels
        let contacts = try await fetchUserContacts()
        let mappedGroups = map(contactGroups: fetchedContactGroups, contacts: contacts)
        contactCacheState.mutate { state in
            state.contactGroups = mappedGroups
            state.isContactGroupInitialized = true
        }
        log?("Successfully retrieved \(mappedGroups.count) contact groups")
        return mappedGroups
    }
    
    /// - Parameters:
    ///   - email: Mail address, e.g. tester@pm.me
    ///   - internalOnly: If true, it will not perform any external lookup, and only provide information from the Proton DB
    public func fetchActivePublicKeys(email: String, internalOnly: Bool = true) async throws -> PublicKeyResponse {
        let query = KeyQuery(email: email, internalOnly: internalOnly)
        if let cache = keyCache.transform({ $0[query] }) {
            return cache
        }

        let request = PublicKeyRequest(email: email, internalOnly: internalOnly)
        log(request: request)
        do {
            let response = try await service.perform(request: request)
            let jsonDict = response.1
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
            let res = try jsonDecoder.decode(PublicKeyResponse.self, from: jsonData)
            keyCache.mutate { cache in
                cache[query] = res
            }
            return res
        } catch {
            log(failedRequest: request, error: error)
            throw error
        }
    }
    
    public func delete(contactID: String) {
        contactCacheState.mutate { state in
            state.contacts.removeAll(where: { $0.id == contactID })
            for index in state.contactGroups.indices {
                state.contactGroups[index].delete(contactID: contactID)
            }
        }
        contactUpdateSubject.send()
    }
    
    public func create(contact: Contact, with emails: [ContactEmail]) {
        var contact = contact
        for email in emails {
            contact.append(contactEmail: email)
        }
        var inserted = false
        contactCacheState.mutate { state in
            guard !state.contacts.contains(where: { $0.id == contact.id }) else { return }
            state.contacts.append(contact)
            inserted = true
        }
        guard inserted else { return }
        contactUpdateSubject.send()
    }
    
    public func update(contact: Contact, with emails: [ContactEmail]) {
        var contact = contact
        for email in emails {
            contact.append(contactEmail: email)
        }
        contactCacheState.mutate { state in
            if let index = state.contacts.firstIndex(where: { $0.id == contact.id }) {
                state.contacts[index] = contact
            } else {
                state.contacts.append(contact)
            }
            for index in state.contactGroups.indices {
                if contact.labelIDs.contains(state.contactGroups[index].id) {
                    state.contactGroups[index].updateOrInsert(contact: contact)
                } else {
                    state.contactGroups[index].delete(contactID: contact.id)
                }
            }
        }
        contactUpdateSubject.send()
    }
    
    public func delete(groupID: String) {
        contactCacheState.mutate { state in
            state.contactGroups.removeAll(where: { $0.id == groupID })
            for index in state.contacts.indices {
                state.contacts[index].remove(labelID: groupID)
            }
        }
        contactUpdateSubject.send()
    }
    
    public func create(group: ContactGroup) {
        var inserted = false
        contactCacheState.mutate { state in
            guard !state.contactGroups.contains(where: { $0.id == group.id }) else { return }
            state.contactGroups.append(group)
            inserted = true
        }
        guard inserted else { return }
        contactUpdateSubject.send()
    }
    
    public func update(group: ContactGroup) {
        var shouldNotify = true
        contactCacheState.mutate { state in
            if let existingGroup = state.contactGroups.first(where: { $0.id == group.id }) {
                let contacts = existingGroup.contacts
                var updatedGroup = group
                updatedGroup.append(contentsOf: contacts)
                guard let index = state.contactGroups.firstIndex(where: { $0.id == updatedGroup.id }) else {
                    shouldNotify = false
                    return
                }
                state.contactGroups[index] = updatedGroup
            } else {
                state.contactGroups.append(group)
            }
        }
        guard shouldNotify else { return }
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
