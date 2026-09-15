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

import PDCore
import ProtonCoreAuthentication

struct VolumeLockFactory {
    @MainActor
    func makeController(localSettings: LocalSettings) -> VolumeLockController {
        VolumeLockController(localSettings: localSettings)
    }

    @MainActor
    func makeCoordinator(
        controller: VolumeLockController,
        tower: Tower,
        authenticator: Authenticator
    ) -> VolumeLockCoordinator {
        let interactor = makeRecoveryInteractor(tower: tower, authenticator: authenticator)
        return VolumeLockCoordinator(controller: controller, recoveryInteractor: interactor)
    }

    func makeEventsListener(controller: VolumeLockController) -> VolumeLockEventsListener {
        VolumeLockEventsListener(controller: controller)
    }

    @MainActor
    func configure(
        controller: VolumeLockController,
        tower: Tower,
        nukeCacheResource: NukeCacheResource = NotificationCenterNukeCacheResource()
    ) {
        controller.configure(
            listShares: { try await tower.client.listShares(showAll: .disabled) },
            nukeCacheResource: nukeCacheResource
        )
    }

    private func makeRecoveryInteractor(tower: Tower, authenticator: Authenticator) -> VolumeLockRecoveryInteractor {
        let selectorRepository = ChildSessionSelectorRepository(
            sessionStorage: tower.sessionVault,
            authenticator: authenticator
        )
        let webSessionInteractor = AuthenticatedWebSessionInteractor(
            sessionStore: tower.sessionVault,
            selectorRepository: selectorRepository,
            encryptionResource: CryptoKitAESGCMEncryptionResource(),
            encodingResource: FoundationEncodingResource()
        )
        let recoveryInteractor = VolumeLockRecoveryInteractor(
            webSessionInteractor: webSessionInteractor,
            configuration: tower.api.configuration
        )
        return recoveryInteractor
    }
}
