// Copyright (c) 2025 Proton AG
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

public struct SharingMemberStartFactory: SharingMemberStartFactoryProtocol {
    public init() {}

    public func makeCoordinator(
        dependencies: SharingMemberStartDependencies,
        node: Node
    ) -> SharingStartCoordinator {
        let shareCreator = ShareCreator(
            storage: dependencies.tower.storage,
            sessionVault: dependencies.tower.sessionVault,
            cloudShareCreator: dependencies.tower.client.createShare,
            signersKitFactory: dependencies.tower.sessionVault,
            moc: dependencies.tower.storage.backgroundContext
        )
        let dependencies = SharingMemberCoordinator.Dependencies(
            baseHost: dependencies.tower.client.service.configuration.baseHost,
            client: dependencies.tower.client,
            contactsManager: dependencies.contactsManager,
            context: dependencies.tower.storage.backgroundContext,
            entitlementsManager: dependencies.tower.entitlementsManager,
            featureFlagsController: dependencies.featureFlagsController,
            node: node,
            rootViewController: dependencies.rootViewController,
            remoteShareMetadataDataSource: dependencies.tower.client,
            sessionVault: dependencies.tower.sessionVault,
            shareCreator: shareCreator,
            storage: dependencies.tower.storage,
            invitationResultController: dependencies.invitationResultController
        )
        return SharingMemberCoordinator(dependencies: dependencies)
    }
}
