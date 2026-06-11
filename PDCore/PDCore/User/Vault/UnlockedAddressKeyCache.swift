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

import Foundation
import ProtonCoreCryptoGoInterface
import ProtonCoreDataModel

final class UnlockedAddressKeyCache: @unchecked Sendable {
    private final class InFlightUnlockedAddressPrivateKeyDerivation {
        let group = DispatchGroup()
        let generation: UInt64
        var result: Result<Data, Error>?

        init(generation: UInt64) {
            self.generation = generation
            group.enter()
        }
    }

    private let unlockedAddressPrivateKeyCache = NSCache<NSString, NSData>()
    private let unlockedAddressPrivateKeyCacheLock = NSLock()
    private let unlockedAddressPrivateKeyCacheLifetime: TimeInterval
    private let unlockedAddressPrivateKeyDerivationWaitTimeout: DispatchTimeInterval

    #if DEBUG
    internal var derivationOverrideForTests: ((Key) throws -> Data)?
    #endif

    weak var derivation: UnlockedAddressKey?

    private let dateResource: DateResource
    private let timerResource: TimerResource
    private var unlockedAddressPrivateKeyCacheLastRefreshedAt: Date
    private var unlockedAddressPrivateKeyCacheExpirationTimer: ScheduledTimerHandle?
    private var unlockedAddressPrivateKeyDerivationsInFlight = [NSString: InFlightUnlockedAddressPrivateKeyDerivation]()
    private var unlockedAddressPrivateKeyCacheGeneration: UInt64 = 0

    init(
        derivation: UnlockedAddressKey?,
        dateResource: DateResource,
        timerResource: TimerResource,
        lifetime: TimeInterval = 10 * 60,
        derivationWaitTimeout: DispatchTimeInterval = .seconds(5),
        countLimit: Int = 15
    ) {
        unlockedAddressPrivateKeyCache.countLimit = countLimit
        self.derivation = derivation
        self.dateResource = dateResource
        self.timerResource = timerResource
        self.unlockedAddressPrivateKeyCacheLifetime = max(0, lifetime)
        self.unlockedAddressPrivateKeyDerivationWaitTimeout = derivationWaitTimeout
        self.unlockedAddressPrivateKeyCacheLastRefreshedAt = dateResource.getDate()
    }

    deinit {
        unlockedAddressPrivateKeyCacheExpirationTimer?.invalidate()
    }

    func unlockedAddressPrivateKeyData(for key: Key) throws -> Data {
        let keyDigest = cacheKey(for: key)

        while true {
            unlockedAddressPrivateKeyCacheLock.lock()

            if let cached = cachedUnlockedAddressPrivateKeyLocked(for: key) {
                unlockedAddressPrivateKeyCacheLock.unlock()
                return cached
            }

            if let existingFlight = unlockedAddressPrivateKeyDerivationsInFlight[keyDigest] {
                unlockedAddressPrivateKeyCacheLock.unlock()

                if existingFlight.group.wait(timeout: .now() + unlockedAddressPrivateKeyDerivationWaitTimeout) == .success,
                   let result = existingFlight.result {
                    return try result.get()
                }

                unlockedAddressPrivateKeyCacheLock.lock()
                if unlockedAddressPrivateKeyDerivationsInFlight[keyDigest] === existingFlight {
                    unlockedAddressPrivateKeyDerivationsInFlight.removeValue(forKey: keyDigest)
                }
                unlockedAddressPrivateKeyCacheLock.unlock()
                continue
            }

            let generation = unlockedAddressPrivateKeyCacheGeneration
            let flight = InFlightUnlockedAddressPrivateKeyDerivation(generation: generation)
            unlockedAddressPrivateKeyDerivationsInFlight[keyDigest] = flight
            unlockedAddressPrivateKeyCacheLock.unlock()

            return try deriveAndPublish(
                for: key,
                cacheKey: keyDigest,
                flight: flight,
                generation: generation
            )
        }
    }

    private func deriveAndPublish(
        for key: Key,
        cacheKey: NSString,
        flight: InFlightUnlockedAddressPrivateKeyDerivation,
        generation: UInt64
    ) throws -> Data {
        let derivationResult: Result<Data, Error>
        do {
            let serialized = try deriveUnlockedAddressPrivateKeyData(for: key)
            derivationResult = .success(serialized)
        } catch {
            derivationResult = .failure(error)
        }

        unlockedAddressPrivateKeyCacheLock.lock()
        flight.result = derivationResult

        if case .success(let data) = derivationResult,
           generation == unlockedAddressPrivateKeyCacheGeneration {
            if cachedUnlockedAddressPrivateKeyLocked(for: key) == nil {
                cacheUnlockedAddressPrivateKeyLocked(data, for: key)
            }
        }

        if unlockedAddressPrivateKeyDerivationsInFlight[cacheKey] === flight {
            unlockedAddressPrivateKeyDerivationsInFlight.removeValue(forKey: cacheKey)
        }
        unlockedAddressPrivateKeyCacheLock.unlock()
        flight.group.leave()

        return try derivationResult.get()
    }

    private func deriveUnlockedAddressPrivateKeyData(for key: Key) throws -> Data {
        #if DEBUG
        if let derivationOverrideForTests {
            return try derivationOverrideForTests(key)
        }
        #endif

        guard let derivation else {
            throw CacheDerivationError.derivationUnavailable
        }

        return try derivation.deriveUnlockedAddressPrivateKeyData(for: key)
    }

    func cachedUnlockedAddressPrivateKey(for key: Key) -> Data? {
        unlockedAddressPrivateKeyCacheLock.lock()
        defer { unlockedAddressPrivateKeyCacheLock.unlock() }
        return cachedUnlockedAddressPrivateKeyLocked(for: key)
    }

    private func cachedUnlockedAddressPrivateKeyLocked(for key: Key) -> Data? {
        clearIfExpiredLocked()
        let keyDigest = cacheKey(for: key)
        return unlockedAddressPrivateKeyCache.object(forKey: keyDigest) as Data?
    }

    func cacheUnlockedAddressPrivateKey(_ data: Data, for key: Key) {
        unlockedAddressPrivateKeyCacheLock.lock()
        defer { unlockedAddressPrivateKeyCacheLock.unlock() }
        cacheUnlockedAddressPrivateKeyLocked(data, for: key)
    }

    private func cacheUnlockedAddressPrivateKeyLocked(_ data: Data, for key: Key) {
        let keyDigest = cacheKey(for: key)
        unlockedAddressPrivateKeyCache.setObject(data as NSData, forKey: keyDigest)
        scheduleExpirationTimerLocked()
    }

    func clear() {
        let now = dateResource.getDate()
        unlockedAddressPrivateKeyCacheLock.lock()
        unlockedAddressPrivateKeyCacheGeneration &+= 1
        unlockedAddressPrivateKeyCacheExpirationTimer?.invalidate()
        unlockedAddressPrivateKeyCacheExpirationTimer = nil
        unlockedAddressPrivateKeyCache.removeAllObjects()
        unlockedAddressPrivateKeyCacheLastRefreshedAt = now
        unlockedAddressPrivateKeyDerivationsInFlight.removeAll()
        unlockedAddressPrivateKeyCacheLock.unlock()
    }

    private func scheduleExpirationTimerLocked() {
        unlockedAddressPrivateKeyCacheExpirationTimer?.invalidate()
        unlockedAddressPrivateKeyCacheLastRefreshedAt = dateResource.getDate()
        unlockedAddressPrivateKeyCacheExpirationTimer = timerResource.scheduledTimer(
            withTimeInterval: unlockedAddressPrivateKeyCacheLifetime,
            repeats: false
        ) { [weak self] in
            self?.clear()
        }
    }

    private func clearIfExpiredLocked() {
        let now = dateResource.getDate()
        if now.timeIntervalSince(unlockedAddressPrivateKeyCacheLastRefreshedAt) >= unlockedAddressPrivateKeyCacheLifetime {
            unlockedAddressPrivateKeyCache.removeAllObjects()
            unlockedAddressPrivateKeyCacheLastRefreshedAt = now
        }
    }

    private func cacheKey(for key: Key) -> NSString {
        let armoredPrivateKey = key.privateKey ?? ""
        let privateKeyDigest = Decryptor.hashSha256(Data(armoredPrivateKey.utf8)).base64EncodedString()
        return "\(key.keyID)|\(privateKeyDigest)" as NSString
    }
}

private enum CacheDerivationError: LocalizedError {
    case derivationUnavailable

    var errorDescription: String? {
        switch self {
        case .derivationUnavailable:
            return "UnlockedAddressKeyCache derivation dependency is unavailable"
        }
    }
}
