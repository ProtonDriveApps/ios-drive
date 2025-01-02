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

class DriveBootstrapStarter: AppBootstrapper {
    private let addressBootstrapper: AppBootstrapper
    private let sharesBootstrapper: AppBootstrapper
    private let eventsBootstrapper: AppBootstrapper
    private let settingsBootstrapper: AppBootstrapper

    init(addressBootstrapper: AppBootstrapper, sharesBootstrapper: AppBootstrapper, eventsBootstrapper: AppBootstrapper, settingsBootstrapper: AppBootstrapper) {
        self.addressBootstrapper = addressBootstrapper
        self.sharesBootstrapper = sharesBootstrapper
        self.eventsBootstrapper = eventsBootstrapper
        self.settingsBootstrapper = settingsBootstrapper
    }

    func bootstrap() async throws {
        try await checkAddresses()
        try await checkRootShares()
        try await checkEvents()
        try await bootstrapAdditionalSettings()
    }

    /// check if we have a valid address downloaded
    private func checkAddresses() async throws {
        try await addressBootstrapper.bootstrap()
    }

    /// Checks if we have a valid main share downloaded
    private func checkRootShares() async throws {
        try await sharesBootstrapper.bootstrap()
    }

    /// Checks if we have a valid initial event downloaded
    private func checkEvents() async throws {
        try await eventsBootstrapper.bootstrap()
    }

    private func bootstrapAdditionalSettings()  async throws {
        try await settingsBootstrapper.bootstrap()
    }
}
