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

import Foundation
import PMEventsManager
import ProtonCoreDataModel
import ProtonCorePayments
import ProtonCoreTelemetry

final class GeneralEventsLoopProcessor: EventLoopProcessor {
    typealias Response = GeneralLoopResponse
    typealias SubscriptionMeta = PMEventsManager.Subscription
    typealias Subscription = ProtonCorePayments.Subscription
    
    private let userVault: UserStorage
    private let userSettingsVault: UserSettingsStorage
    private let addressVault: AddressStorage
    private let paymentsVault: PaymentsStorage
    
    convenience init(sessionVault: SessionVault, generalSettings: GeneralSettings, paymentsVault: PaymentsSecureStorage) {
        self.init(userVault: sessionVault, userSettingsVault: generalSettings, addressVault: sessionVault, paymentsVault: paymentsVault)
    }
    
    init(userVault: UserStorage, userSettingsVault: UserSettingsStorage, addressVault: AddressStorage, paymentsVault: PaymentsStorage) {
        self.userVault = userVault
        self.userSettingsVault = userSettingsVault
        self.addressVault = addressVault
        self.paymentsVault = paymentsVault
    }
    
    func process(response: Response, loopID: String) {
        let isIntegrityCheckNeeded = response.user != nil || response.addresses != nil
        let isAddressMissingBeforeUpdate = isIntegrityCheckNeeded && isAddressMissingInVault()

        if let subscription = response.subscription {
            process(subscription)
        }
        if let user = response.user {
            process(user)
        }
        if let usedSpace = response.usedSpace {
            process(usedSpace)
        }
        if let addresses = response.addresses {
            process(addresses)
        }
        if let userSettings = response.userSettings {
            process(userSettings)
        }

        if isIntegrityCheckNeeded && !isAddressMissingBeforeUpdate && isAddressMissingInVault() {
            logMissingIntegrity(response: response)
        }

        /* Currently not used in the app:
        process(response.organization)
        process(response.invoices)
        process(response.pushes)
        process(response.notices)
        */
    }
    
    func process(_ meta: SubscriptionMeta) {
        paymentsVault.currentSubscription = Subscription(meta)
    }
    
    func process(_ user: User) {
        guard user != userVault.userInfo else { return }
        userVault.storeUser(user)
    }
    
    func process(_ userSettings: UserSettings) {
        userSettingsVault.storeUserSettings(userSettings)
#if os(iOS)
        TelemetryService.shared.setTelemetryEnabled(!userSettings.optOutFromTelementry)
#endif
    }
    
    func process(_ usedSpace: Double) {
        guard let present = userVault.userInfo, present.usedSpace != Int64(usedSpace) else { return }
        let updated = User(ID: present.ID, name: present.name, usedSpace: Int64(usedSpace), usedBaseSpace: present.usedBaseSpace, usedDriveSpace: present.usedDriveSpace, currency: present.currency, credit: present.credit, maxSpace: present.maxSpace, maxBaseSpace: present.maxBaseSpace, maxDriveSpace: present.maxDriveSpace, maxUpload: present.maxUpload, role: present.role, private: present.private, subscribed: present.subscribed, services: present.services, delinquent: present.delinquent, orgPrivateKey: present.orgPrivateKey, email: present.email, displayName: present.displayName, keys: present.keys, lockedFlags: present.lockedFlags)
        userVault.storeUser(updated)
    }
    
    func process(_ addressUpdates: [AddressUpdate]) {
        var processed = [SessionVault.AddressID: Address]()
        
        // add all currently present addresses
        addressVault.addresses?.forEach {
            processed[$0.addressID] = $0
        }
        
        // ids of created and updated - assign to a new version
        // ids of deleted - assing to nil
        addressUpdates.forEach {
            processed[$0.ID] = $0.address
        }
        
        // arrange by order
        var addresses: [Address] = Array(processed.values)
        addresses.sort(by: \.order)
        addressVault.storeAddresses(addresses)
    }
    
    func nukeCache() async {
        NotificationCenter.default.post(name: .nukeCache, object: nil)
    }

    private func isAddressMissingInVault() -> Bool {
        guard let email = userVault.userInfo?.email?.toNilIfEmpty, let addresses = addressVault.addresses else {
            return true
        }
        let isAddressPresent = isContainingAddress(email: email, addresses: addresses)
        return !isAddressPresent
    }

    private func logMissingIntegrity(response: Response) {
        // Verify that user update has email filled in
        if let user = response.user, user.email == nil {
            Log.error("Received a user update with nil email", domain: .events)
            return
        }

        // Verify that addresses updates contain user's email
        guard let email = userVault.userInfo?.email, let updates = response.addresses else {
            return
        }

        let addresses = updates.compactMap(\.address)
        if !isContainingAddress(email: email, addresses: addresses) {
            Log.error("Received a user update with non matching addresses. Updates count: \(updates.count), addresses count: \(addresses.count)", domain: .events)
        }
    }

    private func isContainingAddress(email: String, addresses: [Address]) -> Bool {
        let email = email.canonicalEmailForm
        return addresses.contains { $0.email.canonicalEmailForm == email }
    }
}

// MARK: - Glue code

typealias GeneralEventsLoopWithProcessor = GeneralEventsLoop<GeneralEventsLoopProcessor>

extension ProtonCorePayments.Subscription {
    
    init(_ meta: PMEventsManager.Subscription) {
        self.init(
            start: Date(timeIntervalSince1970: Double(meta.periodStart)),
            end: Date(timeIntervalSince1970: Double(meta.periodEnd)),
            planDetails: meta.plans,
            couponCode: meta.couponCode,
            cycle: meta.cycle,
            amount: meta.amount,
            currency: meta.currency
        )
    }
    
}

protocol UserStorage {
    var userInfo: User? { get }
    func storeUser(_ user: User)
}

protocol UserSettingsStorage {
    func storeUserSettings(_ userSettings: UserSettings)
}

protocol AddressStorage {
    var addresses: [Address]? { get }
    func storeAddresses(_ addresses: [Address])
}

protocol PaymentsStorage: AnyObject {
    var currentSubscription: ProtonCorePayments.Subscription? { get set }
}

extension GeneralSettings: UserSettingsStorage {}
extension SessionVault: UserStorage {}
extension SessionVault: AddressStorage {}
extension PaymentsSecureStorage: PaymentsStorage {}
