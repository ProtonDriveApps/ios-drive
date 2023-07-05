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
}

struct PhotosStateViewData: Equatable {
    let titles: [PhotosStateTitle]
    let rightText: String?
    let progress: Float?

    init(titles: [PhotosStateTitle], rightText: String? = nil, progress: Float? = nil) {
        self.titles = titles
        self.rightText = rightText
        self.progress = progress
    }
}

struct PhotosStateTitle: Equatable {
    let title: String
    let icon: Icon

    enum Icon {
        case lock
        case progress
        case complete
        case failure
        case disabled
    }
}

final class PhotosStateViewModel: PhotosStateViewModelProtocol {
    private let controller: PhotosBackupStateController
    private var cancellables = Set<AnyCancellable>()

    @Published var viewData: PhotosStateViewData?

    init(controller: PhotosBackupStateController) {
        self.controller = controller
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        controller.state
            .sink { [weak self] state in
                self?.handle(state)
            }
            .store(in: &cancellables)
    }

    private func handle(_ state: PhotosBackupState) {
        viewData = makeData(from: state)
    }

    private func makeData(from state: PhotosBackupState) -> PhotosStateViewData? {
        switch state {
        case .empty:
            return nil
        case let .inProgress(progress):
            return makeData(from: progress)
        case .complete:
            return PhotosStateViewData(titles: [.init(title: "Backup complete", icon: .complete)])
        case .restrictedPermissions:
            return PhotosStateViewData(titles: [.init(title: "Permission required for backup", icon: .failure)])
        case .disabled:
            return PhotosStateViewData(titles: [.init(title: "Backup is disabled", icon: .disabled)])
        case .networkConstrained:
            return PhotosStateViewData(titles: makeInProgressTitles())
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
        if leftCount == 0 {
            return nil
        } else if leftCount == 1 {
            return "1 item left"
        } else {
            return "\(leftCount) items left"
        }
    }
}
