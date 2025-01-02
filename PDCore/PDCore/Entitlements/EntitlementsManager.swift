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
import ProtonCoreCryptoGoInterface

public protocol EntitlementsManagerProtocol {
    var hasPublicCollaboration: Bool { get }
    
    func updateEntitlements() async throws
    func updateEntitlementsIfNeeded() async throws
}

public final class EntitlementsManager: EntitlementsManagerProtocol {
    private let client: UserSettingAPIClient
    private let store: EntitlementsStoreProtocol
    private var currentTime: () -> Int64
    private var entitlements: DriveEntitlementsEndpoint.DriveEntitlements? {
        store.loadEntitlementsFromLocalCache()?.entitlements
    }
    public var hasPublicCollaboration: Bool { entitlements?.publicCollaboration ?? false }
    
    init(
        client: UserSettingAPIClient,
        store: EntitlementsStoreProtocol,
        currentTime: @escaping () -> Int64 = { CryptoGo.CryptoGetUnixTime() }
    ) {
        self.client = client
        self.currentTime = currentTime
        self.store = store
    }
    
    public func updateEntitlements() async throws {
        try await fetchRemoteEntitlementsAndSave()
    }
    
    public func updateEntitlementsIfNeeded() async throws {
        guard let (_, updatedTime) = store.loadEntitlementsFromLocalCache() else {
            try await fetchRemoteEntitlementsAndSave()
            return
        }
        if isCacheOutdated(lastUpdatedTime: updatedTime) {
            try await fetchRemoteEntitlementsAndSave()
        }
    }
    
    private func fetchRemoteEntitlementsAndSave() async throws {
        let entitlements = try await client.getDriveEntitlements()
        await MainActor.run {
            store.save(entitlements: entitlements, updateTime: currentTime())
        }
    }
    
    private func isCacheOutdated(lastUpdatedTime: Int64) -> Bool {
        let diff = currentTime() - lastUpdatedTime
        let oneWeek = 7 * 24 * 60 * 60
        return diff > oneWeek
    }
}
