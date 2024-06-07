// Copyright (c) 2023 Proton AG
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
import ProtonCoreKeymaker
import ProtonCoreServices
import UIKit

final class SubscriptionsContainer {
    struct Dependencies {
        let tower: Tower
        let keymaker: Keymaker
        let networkService: PMAPIService
    }

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func makeRootViewController() -> UIViewController {
        let factory = SubscriptionsFactory()
        return factory.makeRootViewController(tower: dependencies.tower, keymaker: dependencies.keymaker, networkService: dependencies.networkService)
    }
}
