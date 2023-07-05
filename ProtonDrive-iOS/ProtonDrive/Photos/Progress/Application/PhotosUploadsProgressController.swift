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

final class LocalPhotosUploadsProgressController: PhotosLoadProgressController {
    private let repository: PhotoUploadsRepository
    private let subject = CurrentValueSubject<PhotosBackupProgress, Never>(.init(total: 0, inProgress: 0))
    private var cancellables = Set<AnyCancellable>()
    private var totalCount: Int

    var progress: AnyPublisher<PhotosBackupProgress, Never> {
        subject.eraseToAnyPublisher()
    }

    init(repository: PhotoUploadsRepository) {
        self.repository = repository
        totalCount = repository.getInitialCount()
        subscribeToUpdates()
    }

    func resetTotal() {
        totalCount = 0
    }

    private func subscribeToUpdates() {
        repository.count
            .removeDuplicates()
            .sink { [weak self] count in
                self?.handleUpdate(count)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ count: Int) {
        let progress = PhotosBackupProgress(total: totalCount, inProgress: count)
        subject.send(progress)
    }
}
