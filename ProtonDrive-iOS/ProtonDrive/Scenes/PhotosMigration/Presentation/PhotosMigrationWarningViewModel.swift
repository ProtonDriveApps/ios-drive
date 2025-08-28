// Copyright (c) 2025 Proton AG
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
import PDLocalization
import PDPhotos

public protocol PhotosMigrationWarningViewModelProtocol {
    var warning: AnyPublisher<String?, Never> { get }
}

final class PhotosMigrationWarningViewModel: PhotosMigrationWarningViewModelProtocol {
    private let controller: PhotoVolumeMigrationControllerProtocol
    private let subject = CurrentValueSubject<String?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()

    var warning: AnyPublisher<String?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(controller: PhotoVolumeMigrationControllerProtocol) {
        self.controller = controller
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        controller.state
            .map { state in
                switch state {
                case .finished, .undetermined:
                    return false
                case .inProgress:
                    return true
                }
            }
            .removeDuplicates()
            .sink { [weak self] isInProgress in
                self?.handleUpdate(isInProgress)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ isInProgress: Bool) {
        if isInProgress {
            subject.send(Localization.photo_migration_banner_text)
        } else {
            subject.send(nil)
        }
    }
}
