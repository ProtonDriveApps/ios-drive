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
}

enum PhotoVolumeBootstrapError: Error {
    case cannotCreatePhotoVolume
}

final class PhotoVolumeBootstrapInteractor: ThrowingAsynchronousInteractor {
    private let localResource: LocalPhotosVolumeFetchResourceProtocol
    private let remoteFetchResource: RemotePhotosVolumeFetchResourceProtocol
    private let createInteractor: CreatePhotoVolumeInteractorProtocol
    private let signersKitFactory: SignersKitFactoryProtocol
    private let eventsStartResource: PhotoVolumeEventsStartResourceProtocol
    private let legacyShareDeleteRepository: LegacyPhotoShareDeleteRepositoryProtocol

    init(
        localResource: LocalPhotosVolumeFetchResourceProtocol,
        remoteFetchResource: RemotePhotosVolumeFetchResourceProtocol,
        createInteractor: CreatePhotoVolumeInteractorProtocol,
        signersKitFactory: SignersKitFactoryProtocol,
        eventsStartResource: PhotoVolumeEventsStartResourceProtocol,
        legacyShareDeleteRepository: LegacyPhotoShareDeleteRepositoryProtocol
    ) {
        self.localResource = localResource
        self.remoteFetchResource = remoteFetchResource
        self.createInteractor = createInteractor
        self.signersKitFactory = signersKitFactory
        self.eventsStartResource = eventsStartResource
        self.legacyShareDeleteRepository = legacyShareDeleteRepository
    }

    func execute(with input: PhotoVolumeBootstrapInput) async throws -> PhotoVolumeBootstrapOutput {
        let localState = try localResource.getLocalState()
        switch localState {
        case let .photoVolume(volumeId):
            Log.info("Local photo volume found, photo volume is bootstrapped.", domain: .albums)
            // Intentionally not starting events, they're already started in the app bootstrap stage
            return .photoVolume(volumeId)
        case .legacyPhotoShare:
            Log.info("Legacy photo share found locally, will delete it and will fetch remote state.", domain: .albums)
            try await legacyShareDeleteRepository.deleteLegacyPhotos()
            return try await executeRemoteState(input: input)
        case .notEnoughData:
            Log.info("No local photo share found, starting remote fetch.", domain: .albums)
            return try await executeRemoteState(input: input)
        }
    }

    private func executeRemoteState(input: PhotoVolumeBootstrapInput) async throws -> PhotoVolumeBootstrapOutput {
        let remoteFetchState = try await remoteFetchResource.getRemoteState()
        switch remoteFetchState {
        case let .photoVolume(volumeId):
            Log.info("Fetched remote photo volume.", domain: .albums)
            await eventsStartResource.startPhotoVolumeEvents(volumeId: volumeId)
            return .photoVolume(volumeId)
        case .noPhotoShare:
            if input.canCreatePhotoVolume {
                return try await createNewVolume()
            } else {
                Log.warning("There's no photo volume on remote, but cannot create new one.", domain: .albums)
                throw PhotoVolumeBootstrapError.cannotCreatePhotoVolume
            }
        }
    }

    private func createNewVolume() async throws -> PhotoVolumeBootstrapOutput {
        Log.info("Will create new photo volume.", domain: .albums)
        let signersKit = try signersKitFactory.make(forSigner: .main)
        let volumeId = try await createInteractor.execute(signersKit: signersKit)
        await eventsStartResource.startPhotoVolumeEvents(volumeId: volumeId)
        return .photoVolume(volumeId)
    }
}
