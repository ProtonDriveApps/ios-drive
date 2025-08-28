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

import PDCore

struct PhotoVolumeMigrationStartInput {
    /// Send `true` when we already know migration is in progress
    let shouldSkipRemoteMigration: Bool

    static let fullStart = PhotoVolumeMigrationStartInput(shouldSkipRemoteMigration: false)
    static let skipRemote = PhotoVolumeMigrationStartInput(shouldSkipRemoteMigration: true)
}
typealias PhotoVolumeMigrationStartOutput = ()

final class PhotoVolumeMigrationStartInteractor: ThrowingAsynchronousInteractor {
    private let remoteStartInteractor: PhotoVolumeMigrationRemoteStartInteractorProtocol
    private let deleteRepository: LegacyPhotoShareDeleteRepositoryProtocol

    init(remoteStartInteractor: PhotoVolumeMigrationRemoteStartInteractorProtocol, deleteRepository: LegacyPhotoShareDeleteRepositoryProtocol) {
        self.remoteStartInteractor = remoteStartInteractor
        self.deleteRepository = deleteRepository
    }

    func execute(with input: PhotoVolumeMigrationStartInput) async throws -> PhotoVolumeMigrationStartOutput {
        if !input.shouldSkipRemoteMigration {
            try await remoteStartInteractor.startMigration()
        }
        try await deleteRepository.deleteLegacyPhotos()
    }
}
