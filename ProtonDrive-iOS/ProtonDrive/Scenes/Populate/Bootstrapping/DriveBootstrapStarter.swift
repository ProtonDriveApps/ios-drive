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
import PDCore
import ProtonCoreKeymaker

class DriveBootstrapStarter: AppBootstrapper {
    private let addressBootstrapper: AppBootstrapper
    private let sharesBootstrapper: AppBootstrapper
    private let volumesBootstrapper: AppBootstrapper
    private let eventsBootstrapper: AppBootstrapper
    private let settingsBootstrapper: AppBootstrapper
    private let photosCacheBootstrapper: AppBootstrapper
    private let tagsMigrationFinishChecker: AppBootstrapper
    private var autoLocker: Autolocker?

    init(addressBootstrapper: AppBootstrapper, sharesBootstrapper: AppBootstrapper, volumesBootstrapper: AppBootstrapper, eventsBootstrapper: AppBootstrapper, settingsBootstrapper: AppBootstrapper, photosCacheBootstrapper: AppBootstrapper, tagsMigrationFinishChecker: AppBootstrapper, autoLocker: Autolocker?) {
        self.addressBootstrapper = addressBootstrapper
        self.sharesBootstrapper = sharesBootstrapper
        self.volumesBootstrapper = volumesBootstrapper
        self.eventsBootstrapper = eventsBootstrapper
        self.settingsBootstrapper = settingsBootstrapper
        self.photosCacheBootstrapper = photosCacheBootstrapper
        self.tagsMigrationFinishChecker = tagsMigrationFinishChecker
        self.autoLocker = autoLocker
    }

    func bootstrap() async throws {
        do {
            if let autoLocker, autoLocker.shouldAutolockNow() {
                Log.debug("Skip bootstrap as autolocking is enabled", domain: .applicationBootstrap)
                return
            }
            try await checkAddresses()
            try await checkRootShares()
            try await checkVolumes() // Intentionally performed only after root shares are checked
            try await checkEvents()
            try await bootstrapAdditionalSettings()
            try await photosCacheBootstrapper.bootstrap()
            try await checkTagsMigrationFinished()
        } catch {
            if let autoLocker, autoLocker.shouldAutolockNow() {
                Log.debug("Ignore bootstrap error as autolocking is enabled", domain: .applicationBootstrap)
            } else {
                throw error
            }
        }
    }

    /// check if we have a valid address downloaded
    private func checkAddresses() async throws {
        try await addressBootstrapper.bootstrap()
        Log.info("Did check addresses", domain: .applicationBootstrap)
    }

    /// Checks if we have a valid main share downloaded
    private func checkRootShares() async throws {
        try await sharesBootstrapper.bootstrap()
        Log.info("Did check root shares", domain: .applicationBootstrap)
    }

    /// Checks if own volumes have a correct type assigned
    private func checkVolumes() async throws {
        try await volumesBootstrapper.bootstrap()
        Log.info("Did check volumes", domain: .applicationBootstrap)
    }

    /// Checks if we have a valid initial event downloaded
    private func checkEvents() async throws {
        try await eventsBootstrapper.bootstrap()
        Log.info("Did check events", domain: .applicationBootstrap)
    }

    private func bootstrapAdditionalSettings()  async throws {
        try await settingsBootstrapper.bootstrap()
        Log.info("Did check additional settings", domain: .applicationBootstrap)
    }

    private func checkTagsMigrationFinished() async throws {
        try await tagsMigrationFinishChecker.bootstrap()
    }
}
