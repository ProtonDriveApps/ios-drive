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
import FileProvider

public struct CacheCleanupStrategy: OptionSet {
    
    public static let cleanMetadata = CacheCleanupStrategy(rawValue: 1 << 1)
    public static let cleanEvents = CacheCleanupStrategy(rawValue: 1 << 2)
    public static let cleanUserSpecificSettings = CacheCleanupStrategy(rawValue: 1 << 3)
    public static let cleanBackupCache = CacheCleanupStrategy(rawValue: 1 << 4)

    public static let cleanEverything: CacheCleanupStrategy = [.cleanEvents, .cleanMetadata, .cleanUserSpecificSettings]
    public static let cleanEverythingButUserSpecificSettings: CacheCleanupStrategy = [.cleanEvents, .cleanMetadata, .cleanBackupCache]
    public static let cleanForClearCache: CacheCleanupStrategy = [.cleanEvents, .cleanMetadata, .cleanBackupCache]
    public static let cleanOnlyMetadataDB: CacheCleanupStrategy = [.cleanMetadata]
    public static let doNotCleanAnything: CacheCleanupStrategy = []

    var shouldCleanEvents: Bool { contains(.cleanEvents) }
    var shouldCleanMetadata: Bool { contains(.cleanMetadata) }
    var shouldCleanUserSpecificSettings: Bool { contains(.cleanUserSpecificSettings) }
    var shouldCleanBackupCache: Bool { contains(.cleanBackupCache) }

    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public protocol DomainOperationsServiceProtocol {
    var cacheCleanupStrategy: CacheCleanupStrategy { get }
    func tearDownConnectionToAllDomains() async throws
    func signalEnumerator() async throws
    func removeAllDomains() async throws
    func groupContainerMigrationStarted() async throws
}

public enum DomainOperationErrors: Error {
    case addDomainFailed(_ error: Error)
    case removeDomainFailed(_ error: Error)
    case reconnectDomainFailed(_ error: Error)
    case disconnectDomainFailed(_ error: Error)
    case getDomainsFailed(_ error: Error)
    case identifyDomainFailed(_ error: Error)
    case signalEnumeratorFailed(_ error: Error)
    case getUserVisibleURLFailed(error: Error)
    case evictItemFailed(error: Error)
    
    case postMigrationStepFailed(_ error: Error)
    
    public var underlyingError: Error {
        switch self {
        case .addDomainFailed(let error), .getDomainsFailed(let error), .disconnectDomainFailed(let error),
             .removeDomainFailed(let error), .reconnectDomainFailed(let error), .identifyDomainFailed(let error),
             .postMigrationStepFailed(let error), .signalEnumeratorFailed(let error),
             .getUserVisibleURLFailed(let error), .evictItemFailed(let error):
            guard let domainOperationError = error as? DomainOperationErrors else { return error }
            return domainOperationError.underlyingError
        }
    }
}

extension DomainOperationErrors: LocalizedError {

    public var errorDescription: String? {
        let nsError = underlyingError as NSError
        switch self {
        case .addDomainFailed:
            return "Adding domain failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .getDomainsFailed:
            return "Getting domains failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .disconnectDomainFailed:
            return "Disconnecting domain failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .removeDomainFailed:
            return "Removing domain failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .reconnectDomainFailed:
            return "Reconnecting domain failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .identifyDomainFailed:
            return "Identifying domain failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .postMigrationStepFailed:
            return "Post-migration step (cleanup) failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .signalEnumeratorFailed:
            return "Signaling enumerator failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .getUserVisibleURLFailed:
            return "Getting user-visible URL failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        case .evictItemFailed:
            return "Evicting item failed with error: \(nsError.localizedDescription), code \(nsError.code), userInfo: \(nsError.userInfo)"
        }
    }
}
