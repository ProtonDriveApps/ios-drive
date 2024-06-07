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

protocol PhotosStateViewModelProtocol: ObservableObject {
    var viewData: PhotosStateViewData? { get }
    func didTapButton(button: PhotosStateButton)
}

enum PhotosStateButton {
    case retry, turnOn
    
    var title: String {
        switch self {
        case .retry:
            return "Retry"
        case .turnOn:
            return "Turn on"
        }
    }
}

struct PhotosStateViewData: Equatable {
    let titles: [PhotosStateTitle]
    let rightText: String?
    let progress: Float?
    let button: PhotosStateButton?

    init(titles: [PhotosStateTitle], rightText: String? = nil, progress: Float? = nil, needsButton button: PhotosStateButton? = nil) {
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
    private var cancellables = Set<AnyCancellable>()

    @Published var viewData: PhotosStateViewData?

    init(
        controller: PhotosBackupStateController,
        coordinator: PhotosStateCoordinator,
        remainingItemsStrategy: PhotosRemainingItemsStrategy,
        numberFormatter: NumberFormatterResource,
        backupStartController: PhotosBackupStartController
    ) {
        self.controller = controller
        self.coordinator = coordinator
        self.remainingItemsStrategy = remainingItemsStrategy
        self.numberFormatter = numberFormatter
        self.backupStartController = backupStartController
        subscribeToUpdates()
    }
    
    func didTapButton(button: PhotosStateButton) {
        switch button {
        case .retry:
            coordinator.openRetryScreen()
        case .turnOn:
            backupStartController.start()
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
            return PhotosStateViewData(titles: [.init(title: "Backup complete", icon: .complete)])
        case .completeWithFailures:
            return PhotosStateViewData(titles: [.init(title: "Backup: issues detected", icon: .completeWithFailures)], needsButton: .retry)
        case .restrictedPermissions:
            return PhotosStateViewData(titles: [.init(title: "Permission required for backup", icon: .failure)])
        case .disabled:
            return PhotosStateViewData(titles: [.init(title: "Backup is disabled", icon: .disabled)], needsButton: .turnOn)
        case .networkConstrained:
            return PhotosStateViewData(titles: [.init(title: "Waiting for WiFi", icon: .noConnection)])
        case .storageConstrained:
            return PhotosStateViewData(titles: [.init(title: "Device storage full", icon: .failure)])
        case .featureFlag:
            return PhotosStateViewData(titles: [.init(title: "The upload of photos is temporarily unavailable", icon: .failure)])
        case .libraryLoading:
            return PhotosStateViewData(titles: [.init(title: "Getting ready to back up", icon: .progress)])
        }
    }

    private func makeData(from progress: PhotosBackupProgress) -> PhotosStateViewData {
        let progressValue = Float(progress.total - progress.inProgress) / Float(progress.total)
        let normalizedProgressValue = min(1, max(0, progressValue))
        return PhotosStateViewData(
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
