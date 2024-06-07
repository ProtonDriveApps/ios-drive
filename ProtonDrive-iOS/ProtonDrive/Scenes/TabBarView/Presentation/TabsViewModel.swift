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

import Combine
import Foundation

protocol TabsViewModel {
    func start()
}

final class ConcreteTabsViewModel: TabsViewModel {
    private let photosTabController: PhotosTabVisibleController
    private let coordinator: TabBarCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(photosTabController: PhotosTabVisibleController, coordinator: TabBarCoordinator) {
        self.photosTabController = photosTabController
        self.coordinator = coordinator
    }

    func start() {
        photosTabController.isEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.coordinator.showPhotosTab()
                } else {
                    self?.coordinator.hidePhotosTab()
                }
            }
            .store(in: &cancellables)
    }
}

final class BlankTabsViewModel: TabsViewModel {
    func start() {}
}
