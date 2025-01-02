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
import PDClient

protocol EntitlementsStoreProtocol: AnyObject {
    typealias Entitlements = DriveEntitlementsEndpoint.DriveEntitlements
    func loadEntitlementsFromLocalCache() -> (entitlements: Entitlements, updatedTime: Int64)?
    func save(entitlements: Entitlements, updateTime: Int64)
}

final class EntitlementsStore: EntitlementsStoreProtocol {
    private let localSettings: LocalSettings
    private lazy var encoder = JSONEncoder()
    private lazy var decoder = JSONDecoder()
    
    init(localSettings: LocalSettings) {
        self.localSettings = localSettings
    }
    
    func loadEntitlementsFromLocalCache() -> (entitlements: Entitlements, updatedTime: Int64)? {
        guard
            let entitlementsValue = localSettings.driveEntitlementsValue,
            let updatedTimeValue = localSettings.driveEntitlementsUpdatedTimeValue
        else { return nil }
        
        do {
            let entitlement = try decoder.decode(DriveEntitlementsEndpoint.DriveEntitlements.self, from: entitlementsValue)
            return (entitlement, updatedTimeValue)
        } catch {
            return nil
        }
    }
    
    func save(entitlements: Entitlements, updateTime: Int64) {
        guard let data = try? encoder.encode(entitlements) else { return }
        localSettings.driveEntitlementsValue = data
        localSettings.driveEntitlementsUpdatedTimeValue = updateTime
    }
}
