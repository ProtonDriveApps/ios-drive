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

import PDContacts
import PDCore
import PDClient
import UIKit

public struct SharingMemberStartDependencies {
    public let tower: Tower
    public let contactsManager: ContactsManagerProtocol
    public let featureFlagsController: FeatureFlagsControllerProtocol
    public let invitationResultController: InvitationResultControllerProtocol?
    public let rootViewController: UIViewController?

    public init(
        tower: Tower,
        contactsManager: ContactsManagerProtocol,
        featureFlagsController: FeatureFlagsControllerProtocol,
        invitationResultController: InvitationResultControllerProtocol?,
        rootViewController: UIViewController?
    ) {
        self.tower = tower
        self.contactsManager = contactsManager
        self.featureFlagsController = featureFlagsController
        self.invitationResultController = invitationResultController
        self.rootViewController = rootViewController
    }
}

public protocol SharingMemberStartFactoryProtocol {
    func makeCoordinator(dependencies: SharingMemberStartDependencies, node: Node) -> SharingStartCoordinator
}
