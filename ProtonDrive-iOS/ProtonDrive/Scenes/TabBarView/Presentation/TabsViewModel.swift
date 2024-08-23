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
import PDCore

protocol TabsViewModel {
    var defaultHomeTabTagPreferences: [Int] { get }
    
    func start()
}

final class ConcreteTabsViewModel: TabsViewModel {
    private let photosTabController: PhotosTabVisibleController
    private let coordinator: TabBarCoordinator
    private var cancellables = Set<AnyCancellable>()
    private let localSettings: LocalSettings
    
    var defaultHomeTabTagPreferences: [Int] {
        [localSettings.defaultHomeTabTag, TabBarItem.photos.tag, TabBarItem.files.tag]
    }

    init(
        photosTabController: PhotosTabVisibleController,
        coordinator: TabBarCoordinator,
        localSettings: LocalSettings
    ) {
        self.photosTabController = photosTabController
        self.coordinator = coordinator
        self.localSettings = localSettings
    }

    func start() {
        photosTabController.isEnabled
            .map { isEnabled in
                return isEnabled
            }
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
    var defaultHomeTabTagPreferences: [Int] { [TabBarItem.files.tag] }
    
    func start() {}
}
