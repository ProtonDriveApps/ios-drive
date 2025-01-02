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
import PDCore
import PDLocalization

protocol PhotosStateViewModelProtocol: ObservableObject {
    var viewData: PhotosStateViewData? { get }
    func didTapButton(button: PhotosStateButton)
}

enum PhotosStateButton {
    case retry
    case turnOn
    case settings
    case useCellular

    var title: String {
        switch self {
        case .retry:
            return Localization.state_retry_button
        case .turnOn:
            return Localization.state_turnOn_button
        case .settings:
            return Localization.state_settings_button
        case .useCellular:
            return Localization.state_use_cellular_button
        }
    }
}

struct PhotosStateViewData: Equatable {
    enum StateType {
        case inProgress
        case complete
        case completeWithFailures
        case disabled
        case restrictedPermissions
        case noConnection
        case noWifi
        case storageConstrained
        case featureFlag
        case libraryLoading
    }

    let type: StateType
    let titles: [PhotosStateTitle]
    let rightText: String?
    let progress: Float?
    let button: PhotosStateButton?

    init(type: StateType, titles: [PhotosStateTitle], rightText: String? = nil, progress: Float? = nil, needsButton button: PhotosStateButton? = nil) {
        self.type = type
        self.titles = titles
        self.rightText = rightText
        self.progress = progress
        self.button = button
    }
}

struct PhotosStateTitle: Equatable {
    let title: String
    let icon: Icon

    enum Icon {
        case lock
        case progress
        case complete
        case completeWithFailures
        case failure
        case disabled
        case noConnection
    }
}

final class PhotosStateViewModel: PhotosStateViewModelProtocol {
    private let controller: PhotosBackupStateController
    private let coordinator: PhotosStateCoordinator
    private let remainingItemsStrategy: PhotosRemainingItemsStrategy
    private let backupStartController: PhotosBackupStartController
    private let settingsController: PhotoBackupSettingsController
    private let messageHandler: UserMessageHandlerProtocol
    private var cancellables = Set<AnyCancellable>()

    @Published var viewData: PhotosStateViewData?

    init(
        controller: PhotosBackupStateController,
        coordinator: PhotosStateCoordinator,
        remainingItemsStrategy: PhotosRemainingItemsStrategy,
        backupStartController: PhotosBackupStartController,
        settingsController: PhotoBackupSettingsController,
        messageHandler: UserMessageHandlerProtocol
    ) {
        self.controller = controller
        self.coordinator = coordinator
        self.remainingItemsStrategy = remainingItemsStrategy
        self.backupStartController = backupStartController
        self.settingsController = settingsController
        self.messageHandler = messageHandler
        subscribeToUpdates()
    }
    
    func didTapButton(button: PhotosStateButton) {
        switch button {
        case .retry:
            coordinator.openRetryScreen()
        case .turnOn:
            backupStartController.start()
        case .settings:
            coordinator.openSystemSettingPage()
        case .useCellular:
            settingsController.setNetworkConnectionConstrained(false)
            messageHandler.handleSuccess(Localization.state_cellular_is_enabled)
        }
        
    }

    private func subscribeToUpdates() {
        controller.state
            .sink { [weak self] state in
                self?.handle(state)
            }
            .store(in: &cancellables)
    }

    private func handle(_ state: PhotosBackupState) {
        let viewData = makeData(from: state)
        if self.viewData != viewData {
            self.viewData = viewData
        }
    }

    private func makeData(from state: PhotosBackupState) -> PhotosStateViewData? {
        switch state {
        case .empty, .quotaConstrained, .applicationStateConstrained:
            return nil
        case let .inProgress(progress):
            return makeData(from: progress)
        case .complete:
            return PhotosStateViewData(type: .complete, titles: [.init(title: Localization.state_backup_complete_title, icon: .complete)])
        case .completeWithFailures:
            return PhotosStateViewData(type: .completeWithFailures, titles: [.init(title: Localization.state_issues_detected_title, icon: .completeWithFailures)], needsButton: .retry)
        case .restrictedPermissions:
            return PhotosStateViewData(type: .restrictedPermissions, titles: [.init(title: Localization.state_permission_required_title, icon: .failure)], needsButton: .settings)
        case .disabled:
            return PhotosStateViewData(type: .disabled, titles: [.init(title: Localization.state_backup_disabled_title, icon: .disabled)], needsButton: .turnOn)
        case let .networkConstrained(constraint):
            switch constraint {
            case .noConnection:
                return PhotosStateViewData(type: .noConnection, titles: [.init(title: Localization.state_disconnection_title, icon: .noConnection)])
            case .noWifi:
                return PhotosStateViewData(type: .noWifi, titles: [.init(title: Localization.state_need_wifi_title, icon: .noConnection)], needsButton: .useCellular)
            }
        case .storageConstrained:
            return PhotosStateViewData(type: .storageConstrained, titles: [.init(title: Localization.state_storage_full_title, icon: .failure)])
        case .featureFlag:
            return PhotosStateViewData(type: .featureFlag, titles: [.init(title: Localization.state_temp_unavailable_title, icon: .failure)])
        case .libraryLoading:
            return PhotosStateViewData(type: .libraryLoading, titles: [.init(title: Localization.state_ready_title, icon: .progress)])
        }
    }

    private func makeData(from progress: PhotosBackupProgress) -> PhotosStateViewData {
        let progressValue = Float(progress.total - progress.inProgress) / Float(progress.total)
        let normalizedProgressValue = min(1, max(0, progressValue))
        return PhotosStateViewData(
            type: .inProgress,
            titles: makeInProgressTitles(),
            rightText: makeProgressRightText(from: progress.inProgress),
            progress: normalizedProgressValue
        )
    }

    private func makeInProgressTitles() -> [PhotosStateTitle] {
        [
            PhotosStateTitle(title: Localization.state_encrypting, icon: .lock),
            PhotosStateTitle(title: Localization.state_backing_up, icon: .progress)
        ]
    }

    private func makeProgressRightText(from leftCount: Int) -> String? {
        guard leftCount > 0 else {
            return nil
        }

        let itemsCount = remainingItemsStrategy.formatRemainingCount(from: leftCount)
        let roundingSign = itemsCount.isRounded ? "+" : ""
        return Localization.progress_status_item_left(items: itemsCount.count, roundingSign: roundingSign)
    }
}
