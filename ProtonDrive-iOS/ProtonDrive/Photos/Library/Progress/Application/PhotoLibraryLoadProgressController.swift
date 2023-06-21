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

typealias PhotoLibraryIds = Set<PhotoLibraryIdentifier>

protocol PhotoLibraryLoadProgressController {
    var progress: AnyPublisher<PhotosBackupProgress, Never> { get }
}

final class LocalPhotoLibraryLoadProgressController: PhotoLibraryLoadProgressController {
    private let interactor: PhotoLibraryLoadProgressActionRepository
    private let subject = CurrentValueSubject<PhotosBackupProgress, Never>(PhotosBackupProgress(total: 0, inProgress: 0))
    private var cancellables = Set<AnyCancellable>()
    private var allIdentifiers = PhotoLibraryIds()
    private var identifiersInProgress = PhotoLibraryIds()

    var progress: AnyPublisher<PhotosBackupProgress, Never> {
        subject.eraseToAnyPublisher()
    }

    init(interactor: PhotoLibraryLoadProgressActionRepository) {
        self.interactor = interactor
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        interactor.action
            .sink { [weak self] action in
                self?.handle(action)
            }
            .store(in: &cancellables)
    }

    private func handle(_ action: PhotoLibraryLoadAction) {
        switch action {
        case let .added(ids):
            allIdentifiers.formUnion(ids)
            identifiersInProgress.formUnion(ids)
        case let .discarded(ids):
            allIdentifiers.subtract(ids)
            identifiersInProgress.subtract(ids)
        case let .finished(ids):
            identifiersInProgress.subtract(ids)
        }
        let progress = PhotosBackupProgress(total: allIdentifiers.count, inProgress: identifiersInProgress.count)
        subject.send(progress)
    }
}
