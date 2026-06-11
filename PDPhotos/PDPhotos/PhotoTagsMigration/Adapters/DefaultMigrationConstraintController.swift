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

import Foundation
import Combine
import PDCore

public final class DefaultMigrationConstraintController: MigrationConstraintController {

    private let networkController: PhotoBackupConstraintController
    private let lockController: PhotoBackupConstraintController
    private let storageController: PhotoBackupConstraintController
    private let photoLibraryAuthorizationController: PhotoLibraryAuthorizationController
    private let volumeObserver: VolumeIdObserver
    private let settingsController: PhotoBackupSettingsController
    private var cancellables = Set<AnyCancellable>()
    private let subject = CurrentValueSubject<(Bool, VolumeID), Never>((false, ""))
    public let isMigrationAllowedPublisher: AnyPublisher<(Bool, VolumeID), Never>
    public var isMigrationAllowed: Bool { subject.value.0 }

    public init(
        networkController: PhotoBackupConstraintController,
        lockController: PhotoBackupConstraintController,
        storageController: PhotoBackupConstraintController,
        photoLibraryAuthorizationController: PhotoLibraryAuthorizationController,
        volumeObserver: VolumeIdObserver,
        settingsController: PhotoBackupSettingsController
    ) {
        self.networkController = networkController
        self.lockController = lockController
        self.storageController = storageController
        self.photoLibraryAuthorizationController = photoLibraryAuthorizationController
        self.volumeObserver = volumeObserver
        self.settingsController = settingsController
        self.isMigrationAllowedPublisher = subject.dropFirst().eraseToAnyPublisher()

        let baseConstraints = Publishers.CombineLatest4(
            networkController.constraint.map { !$0 },
            lockController.constraint.map { !$0 },
            storageController.constraint.map { !$0 },
            photoLibraryAuthorizationController.permissions.map { $0 == .full }
        )

        Publishers.CombineLatest3(
            baseConstraints,
            volumeObserver.volumeIdPublisher,
            settingsController.isEnabled
        )
        .map { base, volumeID, isEnabled in
            let (networkOK, lockOK, storageOK, authOK) = base
            let allOK = networkOK && lockOK && storageOK && authOK && isEnabled

            let message = [
                "Tag migration constraint: \(allOK)",
                "Network: \(networkOK)",
                "Lock: \(lockOK)",
                "Storage: \(storageOK)",
                "Photo library authorization: \(authOK)",
                "Photo volume ID: \(volumeID)",
            ]
            Log.info(message.joined(separator: "\n"), domain: .photosTagMigration)
            return (allOK, volumeID)
        }
        .removeDuplicates {
            $0.0 == $1.0
        }
        .sink { [weak self] event in
            self?.subject.send(event)
        }
        .store(in: &cancellables)
    }
}
