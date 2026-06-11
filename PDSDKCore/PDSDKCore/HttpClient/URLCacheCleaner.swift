// Copyright (c) 2026 Proton AG
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

import ProtonCoreServices
import ProtonCoreUtilities

public protocol URLCacheCleanerProtocol {
    func cleanCacheIfNeeded()
}

public final class NoopURLCacheCleaner: URLCacheCleanerProtocol {
    public static let instance = NoopURLCacheCleaner()
    public func cleanCacheIfNeeded() {}
}

/// Throttles periodic clearing of the PMAPIService session's URL response cache.
public final class URLCacheCleaner: URLCacheCleanerProtocol {
    private let urlCacheClearCounter = Atomic<Int>(0)
    private let numberOfRequestsTillCleanup: Int

    let session: URLCacheClearingSession
    
    public init(session: URLCacheClearingSession, numberOfRequestsTillCleanup: Int = 50) {
        self.session = session
        self.numberOfRequestsTillCleanup = numberOfRequestsTillCleanup
    }
    
    public func cleanCacheIfNeeded() {
        urlCacheClearCounter.mutate { count in
            count += 1
            guard count >= numberOfRequestsTillCleanup else { return }
            
            session.clearURLCache()
            count = 0
        }
    }
}

public protocol URLCacheClearingSession {
    func clearURLCache()
}

/// The session uses its own URLCache instance (not URLCache.shared), so we must
/// access it through the session's configuration to prevent unbounded growth.
extension PMAPIService: URLCacheClearingSession {
    public func clearURLCache() {
        getSession()?.sessionConfiguration.urlCache?.removeAllCachedResponses()
    }
}
