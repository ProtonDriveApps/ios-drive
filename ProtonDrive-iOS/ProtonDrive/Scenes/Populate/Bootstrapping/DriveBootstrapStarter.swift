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

import Combine
import Foundation
import PDCore
import PDCoreIOS
import ProtonCoreKeymaker

class DriveBootstrapStarter: AppBootstrapper {
    private let addressBootstrapper: AppBootstrapper
    private let sharesBootstrapper: AppBootstrapper
    private let volumesBootstrapper: AppBootstrapper
    private let eventsBootstrapper: AppBootstrapper
    private let settingsBootstrapper: AppBootstrapper
    private let photosCacheBootstrapper: AppBootstrapper
    private let tagsMigrationFinishChecker: AppBootstrapper
    private let uploadingPhotosBootrapper: AppBootstrapper
    private let paymentsBootstrapper: AppBootstrapper
    private let autoLocker: Autolocker?
    private let fileManagerBootstrapper: AppBootstrapper
    private let duplicatePhotoListingBootstrapper: AppBootstrapper
    private let sdkBootstrapStarter: AppBootstrapper
    private let bootstrapStateController: BootstrapStateControllerProtocol
    private let sdkRelatedInfrastructureBootstrapper: AppBootstrapper
    private let filePathMigrationBootstrapStarter: AppBootstrapper

    init(
        addressBootstrapper: AppBootstrapper,
        sharesBootstrapper: AppBootstrapper,
        volumesBootstrapper: AppBootstrapper,
        eventsBootstrapper: AppBootstrapper,
        settingsBootstrapper: AppBootstrapper,
        photosCacheBootstrapper: AppBootstrapper,
        tagsMigrationFinishChecker: AppBootstrapper,
        autoLocker: Autolocker?,
        uploadingPhotosBootrapper: AppBootstrapper,
        paymentsBootstrapper: AppBootstrapper,
        fileManagerBootstrapper: AppBootstrapper,
        duplicatePhotoListingBootstrapper: AppBootstrapper,
        sdkBootstrapStarter: AppBootstrapper,
        bootstrapStateController: BootstrapStateControllerProtocol,
        sdkRelatedInfrastructureBootstrapper: AppBootstrapper,
        filePathMigrationBootstrapStarter: AppBootstrapper
    ) {
        self.addressBootstrapper = addressBootstrapper
        self.sharesBootstrapper = sharesBootstrapper
        self.volumesBootstrapper = volumesBootstrapper
        self.eventsBootstrapper = eventsBootstrapper
        self.settingsBootstrapper = settingsBootstrapper
        self.photosCacheBootstrapper = photosCacheBootstrapper
        self.tagsMigrationFinishChecker = tagsMigrationFinishChecker
        self.autoLocker = autoLocker
        self.uploadingPhotosBootrapper = uploadingPhotosBootrapper
        self.paymentsBootstrapper = paymentsBootstrapper
        self.fileManagerBootstrapper = fileManagerBootstrapper
        self.duplicatePhotoListingBootstrapper = duplicatePhotoListingBootstrapper
        self.sdkBootstrapStarter = sdkBootstrapStarter
        self.bootstrapStateController = bootstrapStateController
        self.sdkRelatedInfrastructureBootstrapper = sdkRelatedInfrastructureBootstrapper
        self.filePathMigrationBootstrapStarter = filePathMigrationBootstrapStarter
    }

    func bootstrap() async throws {
        do {
            try await measure(message: "Drive bootstrap", domain: .applicationBootstrap) {
                if let autoLocker, autoLocker.shouldAutolockNow() {
                    Log.debug("Skip bootstrap as autolocking is enabled", domain: .applicationBootstrap)
                    return
                }
                await AppShortcutManager().setShortcutForLoggedInUser()
                // ‼️ Disclaimer: order of some of these matter, only those that don't matter should be inside task group. Update with caution!
                try await fileManagerBootstrapper.bootstrap()
                try await checkAddresses()
                try await sdkBootstrapStarter.bootstrap()
                try await withThrowingTaskGroup { group in
                    group.addTask { try await self.checkRootShares() }
                    group.addTask { try await self.bootstrapAdditionalSettings() }
                    group.addTask { try await self.photosCacheBootstrapper.bootstrap() }
                    group.addTask { try await self.uploadingPhotosBootrapper.bootstrap() }
                    group.addTask { try await self.duplicatePhotoListingBootstrapper.bootstrap() }
                    group.addTask { try await self.sdkRelatedInfrastructureBootstrapper.bootstrap() } // Needs to be callled after SDK bootstrapping!
                    group.addTask { try await self.filePathMigrationBootstrapStarter.bootstrap() }
                    try await group.waitForAll()
                }
                // This awake offlineSaver, needs to be executed after `relocationBootstrapStarter`
                try await checkEvents()
                Task.detached { [weak self] in
                    // Not required for launch
                    try await self?.paymentsBootstrapper.bootstrap()
                    try await self?.checkTagsMigrationFinished()
                }
                bootstrapStateController.setBootstrapped()
            }
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
        try await measure(message: "Check address", domain: .applicationBootstrap) {
            try await addressBootstrapper.bootstrap()
        }
    }

    /// Checks if we have a valid main share downloaded
    private func checkRootShares() async throws {
        try await sharesBootstrapper.bootstrap()
        try await volumesBootstrapper.bootstrap() // Intentionally performed only after root shares are checked
    }

    /// Checks if we have a valid initial event downloaded
    private func checkEvents() async throws {
        try await measure(message: "Check events", domain: .applicationBootstrap) {
            try await eventsBootstrapper.bootstrap()
        }
    }

    private func bootstrapAdditionalSettings()  async throws {
        try await measure(message: "Check additional settings", domain: .applicationBootstrap) {
            try await settingsBootstrapper.bootstrap()
        }
    }

    private func checkTagsMigrationFinished() async throws {
        try await measure(message: "Check tags migration", domain: .applicationBootstrap) {
            try await tagsMigrationFinishChecker.bootstrap()
        }
    }
}
