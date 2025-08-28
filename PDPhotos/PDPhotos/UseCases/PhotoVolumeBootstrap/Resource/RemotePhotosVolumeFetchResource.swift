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
import PDClient

enum RemotePhotosVolumeFetchResult {
    case photoVolume(VolumeID)
    case legacyPhotoShare(VolumeID)
    case noPhotoShare
}

struct RemotePhotosVolumeFetchInput {
    let localLegacyShareVolumeId: String?
}

protocol RemotePhotosVolumeFetchResourceProtocol {
    func getRemoteState(input: RemotePhotosVolumeFetchInput) async throws -> RemotePhotosVolumeFetchResult
}

final class RemotePhotosVolumeFetchResource: RemotePhotosVolumeFetchResourceProtocol {
    private let storageManager: StorageManager
    private let photoShareListing: PhotoShareListing
    private let bootstrapResource: RemotePhotoVolumeBootstrapResourceProtocol
    private let client: Client
    private let legacyShareFetchResource: LegacyPhotoShareFetchResource

    init(
        storageManager: StorageManager,
        photoShareListing: PhotoShareListing,
        bootstrapResource: RemotePhotoVolumeBootstrapResourceProtocol,
        client: Client,
        legacyShareFetchResource: LegacyPhotoShareFetchResource
    ) {
        self.storageManager = storageManager
        self.photoShareListing = photoShareListing
        self.bootstrapResource = bootstrapResource
        self.client = client
        self.legacyShareFetchResource = legacyShareFetchResource
    }

    func getRemoteState(input: RemotePhotosVolumeFetchInput) async throws -> RemotePhotosVolumeFetchResult {
        let volumes = try await client.getVolumes()
        if let remoteVolume = volumes.first(where: { $0.type == .photo && $0.state == .active }) {
            Log.info("Photo volume exists on remote, bootstrapping now.", domain: .albums)
            // Photo volume exists in remote, we can store it.
            return try await bootstrap(photoVolume: remoteVolume)
        } else {
            Log.info("Photo volume doesn't exists on remote, will check legacy photo share.", domain: .albums)
            // Photo volume doesn't exist. We need to validate if old share exists or not.
            return try await bootstrapLegacyShareIfPossible(volumes: volumes, input: input)
        }
    }

    private func bootstrap(photoVolume: PDClient.Volume) async throws -> RemotePhotosVolumeFetchResult {
        try await bootstrapResource.bootstrap(volume: photoVolume)
        return .photoVolume(photoVolume.volumeID)
    }

    private func bootstrapLegacyShareIfPossible(volumes: [PDClient.Volume], input: RemotePhotosVolumeFetchInput) async throws -> RemotePhotosVolumeFetchResult {
        let mainVolume = try volumes.first(where: { $0.type == .main && $0.state == .active }) ?! "Missing main volume"
        let activePhotoShares = try await photoShareListing.getActivePhotoShares()
        guard let legacyShareListing = activePhotoShares.first(where: { $0.volumeID == mainVolume.volumeID }) else {
            Log.info("No legacy photo share on remote.", domain: .albums)
            return .noPhotoShare
        }

        if input.localLegacyShareVolumeId == legacyShareListing.volumeID {
            Log.info("Local photo share equals to remote photo share. Skipping bootstrapping.", domain: .albums)
            return .legacyPhotoShare(legacyShareListing.volumeID)
        } else {
            Log.info("Bootstrapping legacy photo share.", domain: .albums)
            let volumeId = try await legacyShareFetchResource.fetchRemoteShare(with: legacyShareListing)
            return .legacyPhotoShare(volumeId)
        }
    }
}
