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

struct PhotoVolumeBootstrapInput {
    let canCreatePhotoVolume: Bool
}

enum PhotoVolumeBootstrapOutput: Equatable {
    case photoVolume(VolumeID)
    case legacyPhotoShare(VolumeID)
    case migrating
}

enum PhotoVolumeBootstrapError: Error {
    case cannotCreatePhotoVolume
}

final class PhotoVolumeBootstrapInteractor: ThrowingAsynchronousInteractor {
    private let localResource: LocalPhotosVolumeFetchResourceProtocol
    private let remoteFetchResource: RemotePhotosVolumeFetchResourceProtocol
    private let createInteractor: CreatePhotoVolumeInteractorProtocol
    private let migrationStatusInteractor: PhotoVolumeMigrationStatusInteractorProtocol
    private let signersKitFactory: SignersKitFactoryProtocol
    private let eventsStartResource: PhotoVolumeEventsStartResourceProtocol
    private let legacyShareCreateResource: LegacyPhotoShareCreateResource
    private let legacyShareDeleteRepository: LegacyPhotoShareDeleteRepositoryProtocol

    init(
        localResource: LocalPhotosVolumeFetchResourceProtocol,
        remoteFetchResource: RemotePhotosVolumeFetchResourceProtocol,
        createInteractor: CreatePhotoVolumeInteractorProtocol,
        migrationStatusInteractor: PhotoVolumeMigrationStatusInteractorProtocol,
        signersKitFactory: SignersKitFactoryProtocol,
        eventsStartResource: PhotoVolumeEventsStartResourceProtocol,
        legacyShareCreateResource: LegacyPhotoShareCreateResource,
        legacyShareDeleteRepository: LegacyPhotoShareDeleteRepositoryProtocol
    ) {
        self.localResource = localResource
        self.remoteFetchResource = remoteFetchResource
        self.createInteractor = createInteractor
        self.migrationStatusInteractor = migrationStatusInteractor
        self.signersKitFactory = signersKitFactory
        self.eventsStartResource = eventsStartResource
        self.legacyShareCreateResource = legacyShareCreateResource
        self.legacyShareDeleteRepository = legacyShareDeleteRepository
    }

    func execute(with input: PhotoVolumeBootstrapInput) async throws -> PhotoVolumeBootstrapOutput {
        let localState = try localResource.getLocalState()
        switch localState {
        case let .photoVolume(volumeId):
            Log.info("Local photo volume found, photo volume is bootstrapped.", domain: .albums)
            // Intentionally not starting events, they're already started in the app bootstrap stage
            return .photoVolume(volumeId)
        case let .legacyPhotoShare(volumeId):
            Log.info("Legacy photo share found locally.", domain: .albums)
            return try await validateLocalLegacyPhotoShare(volumeId: volumeId, input: input)
        case .notEnoughData:
            Log.info("No local photo share found, starting remote fetch.", domain: .albums)
            return try await executeRemoteState(input: input)
        }
    }

    private func validateLocalLegacyPhotoShare(volumeId: VolumeID, input: PhotoVolumeBootstrapInput) async throws -> PhotoVolumeBootstrapOutput {
        // Local photo share was found. We need to check if the local state is up to date.
        // The migration could have been triggered on another client, or be already done.
        let migrationStatus = try await migrationStatusInteractor.getStatus()
        switch migrationStatus {
        case .inProgress:
            Log.info("Photo share migration already in progress.", domain: .albums)
            return .migrating
        case .finished:
            Log.info("Local share found, but remote has photo volume already. Going to delete local legacy share and fetch new volume from remote.", domain: .albums)
            try await legacyShareDeleteRepository.deleteLegacyPhotos()
            return try await executeRemoteState(input: input)
        case .noPhotoVolume:
            Log.info("Local share found, there's no remote photo volume. Going to fetch the state from remote.", domain: .albums)
            return try await executeRemoteState(input: input, legacyPhotoShareVolumeId: volumeId)
        }
    }

    private func executeRemoteState(input: PhotoVolumeBootstrapInput, legacyPhotoShareVolumeId: String? = nil) async throws -> PhotoVolumeBootstrapOutput {
        let fetchInput = RemotePhotosVolumeFetchInput(localLegacyShareVolumeId: legacyPhotoShareVolumeId)
        let remoteFetchState = try await remoteFetchResource.getRemoteState(input: fetchInput)
        switch remoteFetchState {
        case let .photoVolume(volumeId):
            Log.info("Fetched remote photo volume.", domain: .albums)
            await eventsStartResource.startPhotoVolumeEvents(volumeId: volumeId)
            return .photoVolume(volumeId)
        case let .legacyPhotoShare(volumeId):
            Log.info("Legacy photo share found on BE.", domain: .albums)
            return .legacyPhotoShare(volumeId)
        case .noPhotoShare:
            Log.info("Legacy photo share not found on BE.", domain: .albums)
            if input.canCreatePhotoVolume {
                return try await createNewVolumeIfPossible()
            } else {
                return try await createLegacyPhotoShare()
            }
        }
    }

    private func createNewVolumeIfPossible() async throws -> PhotoVolumeBootstrapOutput {
        // No photo share was found. That can be caused by:
        // - migration happening
        // - migration done, but volume locked
        // - user haven't used photos yet
        let status = try await migrationStatusInteractor.getStatus()
        switch status {
        case .inProgress:
            Log.info("Photo share migration already in progress.", domain: .albums)
            return .migrating
        case .finished:
            Log.error("Migration is finished but remote didn't return photo volume.", error: nil, domain: .albums)
            throw PhotoVolumeBootstrapError.cannotCreatePhotoVolume
        case .noPhotoVolume:
            Log.info("Will try to remove local legacy share if necessary.", domain: .albums)
            try await legacyShareDeleteRepository.deleteLegacyPhotos()
            Log.info("Will create new photo volume.", domain: .albums)
            return try await createNewVolume()
        }
    }

    private func createNewVolume() async throws -> PhotoVolumeBootstrapOutput {
        let signersKit = try signersKitFactory.make(forSigner: .main)
        let volumeId = try await createInteractor.execute(signersKit: signersKit)
        await eventsStartResource.startPhotoVolumeEvents(volumeId: volumeId)
        return .photoVolume(volumeId)
    }

    private func createLegacyPhotoShare() async throws -> PhotoVolumeBootstrapOutput {
        let volumeId = try await legacyShareCreateResource.createLegacyShare()
        return .legacyPhotoShare(volumeId)
    }
}
