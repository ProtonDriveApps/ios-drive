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

public struct CacheCleanupStrategy: OptionSet {
    
    public static let cleanMetadata = CacheCleanupStrategy(rawValue: 1 << 1)
    public static let cleanEvents = CacheCleanupStrategy(rawValue: 1 << 2)
    
    public static let cleanEverything: CacheCleanupStrategy = [.cleanEvents, .cleanMetadata]
    public static let cleanMetadataDBButDoNotCleanEvents: CacheCleanupStrategy = [.cleanMetadata]
    public static let doNotCleanMetadataDBNorEvents: CacheCleanupStrategy = []
    
    var shouldCleanEvents: Bool { contains(.cleanEvents) }
    var shouldCleanMetadata: Bool { contains(.cleanMetadata) }
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public protocol DomainConnectionManagerProtocol {
    var cacheCleanupStrategy: CacheCleanupStrategy { get }
    func tearDownDomain() async throws
    func signalEnumerator() async throws
    func forceDomainRemoval() async throws
}
