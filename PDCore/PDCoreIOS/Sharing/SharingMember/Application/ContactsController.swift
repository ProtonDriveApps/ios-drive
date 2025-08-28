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

import Combine
import Foundation
import PDContacts
import PDLocalization

public protocol ContactsControllerProtocol {
    func fetchContacts() async throws -> IntegralContacts
    func fetchInternalPublicKey(email: String) async throws -> [Key]
    func name(of email: String) async -> String?
}

/// ContactsManager wrapper
public final class ContactsController: ContactsControllerProtocol {
    private let contactsManager: ContactsManagerProtocol
    private let store = ContactsStore()
    private var cancellables = Set<AnyCancellable>()
    
    public init(contactsManager: ContactsManagerProtocol) {
        self.contactsManager = contactsManager
        subscribeForUpdate()
    }
    
    private func subscribeForUpdate() {
        contactsManager.contactUpdatedNotifier
            .sink { [weak self] _ in
                self?.handleContactUpdate()
            }
            .store(in: &cancellables)
    }

    private func handleContactUpdate() {
        Task { [weak self] in
            try await self?.fetchAndStoreIntegralContacts()
        }
    }

    /// Retrieve user contacts:
    /// if they are available in the in-memory cache, return them from there;
    /// otherwise, query the backend.
    /// This function is not thread-safe.
    /// If the in-memory cache is unavailable, it may make multiple calls to the backend API.
    public func fetchContacts() async throws -> IntegralContacts {
        do {
            if await store.status == .fetched {
                return await store.export()
            }
            await store.update(status: .fetching)
            try await fetchAndStoreIntegralContacts()
            return await store.export()
        } catch {
            throw ContactErrors.unableToFetch
        }
    }
    
    private func fetchAndStoreIntegralContacts() async throws {
        let (contacts, contactGroups) = try await contactsManager.fetchIntegralContacts()
        let basicContacts = transfer(contacts: contacts)
        await store.update(basicContacts: basicContacts, contactGroups: contactGroups)
        await store.update(status: .fetched)
    }
    
    public func fetchInternalPublicKey(email: String) async throws -> [Key] {
        let res = try await contactsManager.fetchActivePublicKeys(email: email, internalOnly: true)
        return res.address.keys
    }
    
    public func name(of email: String) async -> String? {
        let basicContacts = await store.basicContacts
        return basicContacts.first(where: { $0.email == email })?.name
    }
    
    private func transfer(contacts: [Contact]) -> [BasicContact] {
        var basicContacts: [BasicContact] = []
        for contact in contacts {
            for contactEmail in contact.contactEmails {
                basicContacts.append(
                    .init(
                        contactID: contact.id,
                        name: contact.name,
                        email: contactEmail.email,
                        lastUsedTime: contactEmail.lastUsedTime
                    )
                )
            }
        }
        return basicContacts
    }
}

extension ContactsController {
    private actor ContactsStore {
        var status: FetchStatus = .initialize
        var basicContacts: [BasicContact] = []
        var contactGroups: [ContactGroup] = []
        
        func update(basicContacts: [BasicContact], contactGroups: [ContactGroup]) {
            self.basicContacts = basicContacts
            self.contactGroups = contactGroups
        }
        
        func update(status: FetchStatus) {
            self.status = status
        }
        
        func export() -> IntegralContacts {
            .init(basicContacts: basicContacts, contactGroups: contactGroups)
        }
    }
    
    private enum FetchStatus {
        case initialize, fetching, fetched
    }
}
