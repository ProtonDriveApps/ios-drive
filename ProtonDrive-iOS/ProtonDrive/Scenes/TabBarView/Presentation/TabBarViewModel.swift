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
import PDCoreIOS

protocol TabBarViewModelProtocol {
    var currentTabItem: TabBarItem { get }
    var defaultHomeTab: Int { get }
    var isTabBarHidden: AnyPublisher<Bool, Never> { get }
    func selectTab(tag: Int)
    func reportPerformance(selectedIndex: Int)
}

final class TabBarViewModel: TabBarViewModelProtocol {

    private let coordinator: TabBarCoordinatorProtocol
    private var cancellables = Set<AnyCancellable>()
    private let scrollToTopSubject: PassthroughSubject<TabBarItem, Never>
    private let localSettings: LocalSettings
    private let volumeIdsController: SharedVolumeIdsController
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let ratingBoosterFlowController: RatingBoosterFlowControllerProtocol
    private let performanceMetricsController: PerformanceMetricsControllerProtocol?
    private(set) var currentTabItem: TabBarItem
    private var hasSharing: Bool
    private var hasInitialized = false
    private var deepLinkNotification: DeepLinkNotification?

    let isTabBarHidden: AnyPublisher<Bool, Never>

    init(
        isTabBarHiddenPublisher: AnyPublisher<Bool, Never>,
        scrollToTopSubject: PassthroughSubject<TabBarItem, Never>,
        coordinator: TabBarCoordinatorProtocol,
        localSettings: LocalSettings,
        volumeIdsController: SharedVolumeIdsController,
        featureFlagsController: FeatureFlagsControllerProtocol,
        ratingBoosterFlowController: RatingBoosterFlowControllerProtocol,
        performanceMetricsController: PerformanceMetricsControllerProtocol?,
        deepLinkNotification: DeepLinkNotification?
    ) {
        self.isTabBarHidden = isTabBarHiddenPublisher
        self.scrollToTopSubject = scrollToTopSubject
        self.coordinator = coordinator
        self.localSettings = localSettings
        self.volumeIdsController = volumeIdsController
        self.featureFlagsController = featureFlagsController
        self.ratingBoosterFlowController = ratingBoosterFlowController
        self.performanceMetricsController = performanceMetricsController
        self.deepLinkNotification = deepLinkNotification
        currentTabItem = deepLinkNotification?.tab ?? TabBarItem(rawValue: localSettings.defaultHomeTabTag) ?? .files
        hasSharing = featureFlagsController.hasSharing
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        featureFlagsController.updatePublisher
            .map { [featureFlagsController] in
                featureFlagsController.hasSharing
            }
            .filter { [weak self] value in
                self?.hasSharing != value
            }
            .sink { [weak self] value in
                self?.hasSharing = value
                self?.coordinator.regenerateChildren()
            }
            .store(in: &cancellables)
    }

    var defaultHomeTab: Int {
        localSettings.defaultHomeTabTag
    }

    func selectTab(tag: Int) {
        guard let item = TabBarItem(rawValue: tag) else { return }
        sendScrollToTopIfNeeded(item: item)
        defer { currentTabItem = item }
        guard featureFlagsController.hasSharing else {
            return
        }

        if currentTabItem == .sharedWithMe && item != currentTabItem {
            // Moving away from sharedWithMe means no shared volume should be marked as active
            volumeIdsController.resignActiveSharedVolume()
        } else if currentTabItem == .photos && item != .photos {
            volumeIdsController.resignActiveSharedVolume()
        }
        ratingBoosterFlowController.navigationDidHappen()
    }

    private func sendScrollToTopIfNeeded(item: TabBarItem) {
        guard currentTabItem == item else { return }
        switch item.tag {
        case TabBarItem.files.tag:
            scrollToTopSubject.send(.files)
        case TabBarItem.photos.tag:
            scrollToTopSubject.send(.photos)
        case TabBarItem.shared.tag:
            scrollToTopSubject.send(.shared)
        case TabBarItem.sharedWithMe.tag:
            scrollToTopSubject.send(.sharedWithMe)
        default: break
        }
    }

    func reportPerformance(selectedIndex: Int) {
        guard
            let item = TabBarItem(rawValue: selectedIndex),
            currentTabItem.tag != item.tag || !hasInitialized
        else { return }
        performanceMetricsController?.startRecord(pageType: item.toMetricTag)
    }
}

extension TabBarItem {
    var toMetricTag: PerformanceMetric.PageType {
        switch self {
        case .files:
            return .myFiles
        case .photos:
            return .photos
        case .shared:
            return .sharedByMe
        case .sharedWithMe:
            return .sharedWithMe
        case .computers:
            return .computers
        }
    }
}
