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

import Foundation
import PDCore
import PDCoreIOS
import SwiftUI
import UIKit

public final class StorageBonusPromoContainer {
    public struct Dependencies {
        let tower: Tower

        public init(tower: Tower) {
            self.tower = tower
        }
    }

    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeRootViewController() -> UIViewController {
        let factory = StorageBonusPromoFactory()
        return factory.makeStorageBonusChecklistView(tower: dependencies.tower)
    }
}

struct StorageBonusPromoFactory {

    func makeStorageBonusChecklistView(tower: Tower) -> UIViewController {
        let repository = makeStoragePromoBonusStatusRepository(tower: tower)
        let viewModel = StorageBonusChecklistViewModel(repository: repository)
        let view = StorageBonusChecklistView(viewModel: viewModel)
        let viewController = UIHostingController(rootView: view)
        return ModalNavigationViewController(rootViewController: viewController)
    }

    func makeShowStorageBonusPromoInteractor(tower: Tower) -> ShowStorageBonusPromoInteractorProtocol {
        let dateResource = PlatformCurrentDateResource()
        let repository = makeStoragePromoBonusStatusRepository(tower: tower)
        let showStorageInteractor = ShowStorageBonusPromoInteractor(dateResource: dateResource, repository: repository)
        return showStorageInteractor
    }

    func makeStoragePromoBonusStatusRepository(tower: Tower) -> StorageBonusPromoStatusRepositoryProtocol {
        let dateResource = PlatformCurrentDateResource()
        let repository = StoragePromoBonusStatusRepository(remoteDataSource: tower.client, localSettings: tower.localSettings, dateResource: dateResource)
        return repository
    }

}
