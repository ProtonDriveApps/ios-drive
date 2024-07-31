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
            return "Retry"
        case .turnOn:
            return "Turn on"
        case .settings:
            return "Settings"
        case .useCellular:
            return "Use Cellular"
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
    private let numberFormatter: NumberFormatterResource
    private let backupStartController: PhotosBackupStartController
    private let settingsController: PhotoBackupSettingsController
    private let messageHandler: UserMessageHandlerProtocol
    private var cancellables = Set<AnyCancellable>()

    @Published var viewData: PhotosStateViewData?

    init(
        controller: PhotosBackupStateController,
        coordinator: PhotosStateCoordinator,
        remainingItemsStrategy: PhotosRemainingItemsStrategy,
        numberFormatter: NumberFormatterResource,
        backupStartController: PhotosBackupStartController,
        settingsController: PhotoBackupSettingsController,
        messageHandler: UserMessageHandlerProtocol
    ) {
        self.controller = controller
        self.coordinator = coordinator
        self.remainingItemsStrategy = remainingItemsStrategy
        self.numberFormatter = numberFormatter
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
            messageHandler.handleSuccess("Photos backup is now allowed also on mobile data")
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
            return PhotosStateViewData(type: .complete, titles: [.init(title: "Backup complete", icon: .complete)])
        case .completeWithFailures:
            return PhotosStateViewData(type: .completeWithFailures, titles: [.init(title: "Backup: issues detected", icon: .completeWithFailures)], needsButton: .retry)
        case .restrictedPermissions:
            return PhotosStateViewData(type: .restrictedPermissions, titles: [.init(title: "Permission required for backup", icon: .failure)], needsButton: .settings)
        case .disabled:
            return PhotosStateViewData(type: .disabled, titles: [.init(title: "Backup is disabled", icon: .disabled)], needsButton: .turnOn)
        case let .networkConstrained(constraint):
            switch constraint {
            case .noConnection:
                return PhotosStateViewData(type: .noConnection, titles: [.init(title: "No internet connection", icon: .noConnection)])
            case .noWifi:
                return PhotosStateViewData(type: .noWifi, titles: [.init(title: "Wi-Fi needed for backup", icon: .noConnection)], needsButton: .useCellular)
            }
        case .storageConstrained:
            return PhotosStateViewData(type: .storageConstrained, titles: [.init(title: "Device storage full", icon: .failure)])
        case .featureFlag:
            return PhotosStateViewData(type: .featureFlag, titles: [.init(title: "The upload of photos is temporarily unavailable", icon: .failure)])
        case .libraryLoading:
            return PhotosStateViewData(type: .libraryLoading, titles: [.init(title: "Getting ready to back up", icon: .progress)])
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
            PhotosStateTitle(title: "Encrypting...", icon: .lock),
            PhotosStateTitle(title: "Backing up...", icon: .progress)
        ]
    }

    private func makeProgressRightText(from leftCount: Int) -> String? {
        guard leftCount > 0 else {
            return nil
        }

        let itemsCount = remainingItemsStrategy.formatRemainingCount(from: leftCount)
        let formattedCount = numberFormatter.format(itemsCount.count)
        let roundingSign = itemsCount.isRounded ? "+" : ""
        if itemsCount.count == 1 {
            return "\(formattedCount)\(roundingSign) item left"
        } else {
            return "\(formattedCount)\(roundingSign) items left"
        }
    }
}
