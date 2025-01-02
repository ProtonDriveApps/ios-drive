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
import PDUIComponents

protocol PhotosStorageViewModelProtocol: ObservableObject {
    var data: PhotosStorageViewData? { get }
    func openStorageOptions()
    func close()
}

struct PhotosStorageViewData: Equatable {
    let severance: WarningBadgeSeverance
    let title: String
    let items: String?
    let text: String?
    let storageButton: String
    let closeButton: String?
    let accessibilityIdentifier: String
}

final class PhotosStorageViewModel: PhotosStorageViewModelProtocol {
    private let quotaStateController: QuotaStateController
    private let progressController: PhotosBackupProgressController
    private let dataFactory: PhotosStorageViewDataFactory
    private let coordinator: PhotosStorageCoordinator
    private var cancellables = Set<AnyCancellable>()

    @Published var data: PhotosStorageViewData?

    init(quotaStateController: QuotaStateController, progressController: PhotosBackupProgressController, dataFactory: PhotosStorageViewDataFactory, coordinator: PhotosStorageCoordinator) {
        self.quotaStateController = quotaStateController
        self.progressController = progressController
        self.dataFactory = dataFactory
        self.coordinator = coordinator
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(quotaStateController.state, progressController.progress)
            .removeDuplicates(by: { $0.0 == $1.0 })
            .sink { [weak self] value in
                self?.handle(state: value.0, progress: value.1)
            }
            .store(in: &cancellables)
    }

    private func handle(state: QuotaState?, progress: PhotosBackupProgress?) {
        data = state.map { dataFactory.makeData(state: $0, progress: progress) }
    }

    func openStorageOptions() {
        coordinator.openSubscriptions()
    }

    func close() {
        data = nil
    }
}
