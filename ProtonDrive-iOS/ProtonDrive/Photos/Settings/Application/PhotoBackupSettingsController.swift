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

protocol PhotoBackupSettingsController {
    var isEnabled: AnyPublisher<Bool, Never> { get }
    func setEnabled(_ isEnabled: Bool)
}

final class LocalPhotoBackupSettingsController: PhotoBackupSettingsController {
    private let localSettings: LocalSettings
    private let isEnabledSubject: CurrentValueSubject<Bool, Never>
    private var cancellables = Set<AnyCancellable>()

    var isEnabled: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }

    init(localSettings: LocalSettings) {
        self.localSettings = localSettings
        isEnabledSubject = .init(localSettings.isPhotosBackupEnabled)
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        localSettings.publisher(for: \.isPhotosBackupEnabled)
            .sink { [weak self] value in
                self?.isEnabledSubject.send(value)
            }
            .store(in: &cancellables)
    }

    func setEnabled(_ isEnabled: Bool) {
        localSettings.isPhotosBackupEnabled = isEnabled
    }
}
