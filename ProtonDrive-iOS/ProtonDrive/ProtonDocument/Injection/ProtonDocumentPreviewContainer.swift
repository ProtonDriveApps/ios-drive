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

import UIKit
import PDCore
import ProtonCoreServices
import ProtonCoreAuthentication

final class ProtonDocumentPreviewContainer {
    struct Dependencies {
        let tower: Tower
        let featureFlagsController: FeatureFlagsController
        let apiService: PMAPIService
        let authenticator: Authenticator
    }

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func makeController(rootViewController: UIViewController?) -> ProtonDocumentOpeningControllerProtocol {
        return ProtonDocumentPreviewFactory().makeController(
            rootViewController: rootViewController,
            container: self,
            tower: dependencies.tower,
            featureFlagsController: dependencies.featureFlagsController
        )
    }

    func makePreviewViewController(
        identifier: ProtonDocumentIdentifier,
        coordinator: ProtonDocumentCoordinatorProtocol,
        openingController: ProtonDocumentOpeningControllerProtocol
    ) -> UIViewController {
        return ProtonDocumentPreviewFactory().makePreviewViewController(
            identifier: identifier,
            coordinator: coordinator,
            tower: dependencies.tower,
            authenticator: dependencies.authenticator,
            openingController: openingController
        )
    }

    func makeRenameViewController(identifier: ProtonDocumentIdentifier) -> UIViewController? {
        return ProtonDocumentPreviewFactory().makeRenameViewController(
            identifier: identifier,
            tower: dependencies.tower
        )
    }
}
