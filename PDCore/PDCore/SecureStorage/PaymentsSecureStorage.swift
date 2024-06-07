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
import ProtonCoreKeymaker
import ProtonCorePayments

public final class PaymentsSecureStorage: Keychain {
    
    private let mainKeyProvider: MainKeyProvider
    
    @SecureStorage(label: Key.currentSubscription) private(set) var _currentSubscription: Subscription?
    
    public init(mainKeyProvider: MainKeyProvider) {
        let keychainGroup = Constants.developerGroup + Constants.appGroup
        self.mainKeyProvider = mainKeyProvider
        super.init(service: "ch.protonmail", accessGroup: keychainGroup)
        
        self.__currentSubscription.configure(with: mainKeyProvider)
    }
        
    struct Key {
        static let servicePlans = "servicePlans"
        static let currentSubscription = "currentSubscription"
        static let defaultPlanDetails = "defaultPlanDetails"
        static let paymentsBackendStatusAcceptsIAP = "paymentsBackendStatusAcceptsIAP"
        static let paymentMethods = "paymentMethods"
        static let credits = "credits"
    }
}

extension PaymentsSecureStorage: ServicePlanDataStorage {
    
    public var servicePlansDetails: [Plan]? {
        get {
            guard let data = data(forKey: Key.servicePlans) else {
                return nil
            }
            return try? JSONDecoder().decode([Plan].self, from: data)
        }
        set(newValue) {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            set(data, forKey: Key.servicePlans)
        }
    }
    
    public var defaultPlanDetails: Plan? {
        get {
            guard let data = data(forKey: Key.defaultPlanDetails) else {
                return nil
            }
            return try? JSONDecoder().decode(Plan.self, from: data)
        }
        set(newValue) {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            set(data, forKey: Key.defaultPlanDetails)
        }
    }
    
    public var currentSubscription: Subscription? {
        get { _currentSubscription }
        set(newValue) {
            _currentSubscription = newValue
        }
    }
    
    public var paymentsBackendStatusAcceptsIAP: Bool {
        get {
            guard let data = data(forKey: Key.paymentsBackendStatusAcceptsIAP) else {
                return false
            }
            let value = (try? JSONDecoder().decode(Bool.self, from: data)) ?? false
            return value
        }
        set(newValue) {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            set(data, forKey: Key.paymentsBackendStatusAcceptsIAP)
        }
    }
    
    public var paymentMethods: [PaymentMethod]? {
        get {
            guard let data = data(forKey: Key.paymentMethods) else {
                return nil
            }
            return try? JSONDecoder().decode([PaymentMethod].self, from: data)
        }
        set(newValue) {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            set(data, forKey: Key.paymentMethods)
        }
    }
    
    public var credits: Credits? {
        get {
            guard let data = data(forKey: Key.credits) else {
                return nil
            }
            return try? JSONDecoder().decode(Credits.self, from: data)
        }
        set(newValue) {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            set(data, forKey: Key.credits)
        }
    }
    
}

extension Credits: Codable {

    enum CodingKeys: CodingKey {
      case credit, currency
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(credit, forKey: .credit)
        try container.encode(currency, forKey: .currency)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let credit = try container.decode(Double.self, forKey: .credit)
        let currency = try container.decode(String.self, forKey: .currency)
        self.init(credit: credit, currency: currency)
    }

}
