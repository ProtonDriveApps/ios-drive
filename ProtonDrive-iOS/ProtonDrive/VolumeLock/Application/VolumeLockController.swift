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

import Combine
import Foundation
import PDClient
import PDCore

@MainActor
final class VolumeLockController: ObservableObject {
    @Published private(set) var isVolumeLocked = false
    @Published private(set) var isBannerDismissed = false

    var shouldShowBanner: Bool {
        isVolumeLocked && !isSkippedForCurrentLockedShares && !isBannerDismissed
    }

    private(set) var currentLockedShareIDs: Set<String> = []

    private let localSettings: LocalSettings
    private let volumeLockShareStrategy: VolumeLockShareStrategy
    private var listShares: (() async throws -> [ListSharesEndpoint.Response.Share])?
    private var nukeCacheResource: NukeCacheResource?
    private var inFlightCheck: Task<Void, Never>?
    private var isNukingCache = false

    init(
        localSettings: LocalSettings,
        volumeLockShareStrategy: VolumeLockShareStrategy = DefaultVolumeLockShareStrategy()
    ) {
        self.localSettings = localSettings
        self.volumeLockShareStrategy = volumeLockShareStrategy
    }

    func configure(
        listShares: @escaping () async throws -> [ListSharesEndpoint.Response.Share],
        nukeCacheResource: NukeCacheResource
    ) {
        self.listShares = listShares
        self.nukeCacheResource = nukeCacheResource
    }

    func handleVolumeLockHint() async {
        guard let listShares else { return }
        do {
            let shares = try await listShares()
            guard volumeLockShareStrategy.isVolumeLocked(shares: shares) else { return }
            updateLockedShareIDs(from: shares)
            isVolumeLocked = true
            beginLockedVolumeRecoveryIfNeeded()
        } catch {
            Log.error("List all shares failed", error: error, domain: .application)
        }
    }

    func check(userInitiated: Bool) async {
        await refreshLockState(triggeringRecovery: true)
        if userInitiated, isVolumeLocked, !isSkippedForCurrentLockedShares {
            isBannerDismissed = false
        }
    }

    func checkSilently() async {
        guard isVolumeLocked else { return }
        await refreshLockState(triggeringRecovery: true)
    }

    func applyShareBootstrapResult(lockedShares: [ListSharesEndpoint.Response.Share]) {
        // This contains all locked shares
        currentLockedShareIDs = Set(lockedShares.map(\.shareID))
        isVolumeLocked = !lockedShares.isEmpty
        if isVolumeLocked, !isSkippedForCurrentLockedShares {
            isBannerDismissed = false
        }
    }

    /// Clears the in-flight nuke guard after populate finishes (success or failure).
    func finishPopulate() {
        isNukingCache = false
    }

    func dismissBanner() {
        isBannerDismissed = true
    }

    func skipBannerPermanently() {
        localSettings.skipVolumeLockShares(withIDs: Array(currentLockedShareIDs))
        objectWillChange.send()
    }

    func resetBannerVisibilityForMyFilesAppear() {
        guard isVolumeLocked, !isSkippedForCurrentLockedShares else { return }
        isBannerDismissed = false
    }

    private var isSkippedForCurrentLockedShares: Bool {
        !currentLockedShareIDs.isEmpty
            && currentLockedShareIDs.isSubset(of: Set(localSettings.skippedVolumeLockShareIDs))
    }

    private func refreshLockState(triggeringRecovery: Bool) async {
        if let inFlightCheck {
            await inFlightCheck.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshLockStateOnce(triggeringRecovery: triggeringRecovery)
        }
        inFlightCheck = task
        await task.value
        inFlightCheck = nil
    }

    private func refreshLockStateOnce(triggeringRecovery: Bool) async {
        guard let listShares else { return }

        do {
            let shares = try await listShares()
            if volumeLockShareStrategy.isVolumeLocked(shares: shares) {
                updateLockedShareIDs(from: shares)
                isVolumeLocked = true
                return
            }

            if volumeLockShareStrategy.isVolumeUnlocked(shares: shares) {
                let wasLocked = isVolumeLocked
                isVolumeLocked = false
                currentLockedShareIDs = []
                isBannerDismissed = false
                if triggeringRecovery, wasLocked {
                    nukeCacheResource?.nukeCache(reason: "Volume unlocked")
                }
            }
        } catch {
            Log.error("Volume lock check failed", error: error, domain: .application)
        }
    }

    private func updateLockedShareIDs(from shares: [ListSharesEndpoint.Response.Share]) {
        currentLockedShareIDs = volumeLockShareStrategy.lockedShareIDs(in: shares)
    }

    private func beginLockedVolumeRecoveryIfNeeded() {
        guard !isNukingCache else { return }
        isNukingCache = true
        nukeCacheResource?.nukeCache(reason: "Volume is locked")
    }
}
