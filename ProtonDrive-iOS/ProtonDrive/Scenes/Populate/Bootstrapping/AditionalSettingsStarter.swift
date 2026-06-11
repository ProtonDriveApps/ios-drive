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

class AditionalSettingsStarter: AppBootstrapper {
    let driveSettingsInitializer: DriveUserSettingsInitializerInteractorProtocol
    let protonSettingsInitializer: ProtonUserSettingsStarterInteractorProtocol
    let b2bUserStatusStarter: B2BUserStatusStarterProtocol
    let checklistBootstrapper: DriveChecklistBootstrapper

    init(
        driveSettingsInitializer: DriveUserSettingsInitializerInteractorProtocol,
        protonSettingsInitializer: ProtonUserSettingsStarterInteractorProtocol,
        b2bUserStatusStarter: B2BUserStatusStarter,
        checklistBootstrapper: DriveChecklistBootstrapper
    ) {
        self.driveSettingsInitializer = driveSettingsInitializer
        self.protonSettingsInitializer = protonSettingsInitializer
        self.b2bUserStatusStarter = b2bUserStatusStarter
        self.checklistBootstrapper = checklistBootstrapper
    }

    func bootstrap() async throws {
        async let _ = try await driveSettingsInitializer.bootstrap()
        async let _ = try await protonSettingsInitializer.bootstrap()
        async let _ = try await b2bUserStatusStarter.bootstrap()
        Task.detached { [weak self] in
            try? await self?.checklistBootstrapper.bootstrap()
        }
    }
}
