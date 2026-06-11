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
    case noPhotoShare
}

protocol RemotePhotosVolumeFetchResourceProtocol {
    func getRemoteState() async throws -> RemotePhotosVolumeFetchResult
}

final class RemotePhotosVolumeFetchResource: RemotePhotosVolumeFetchResourceProtocol {
    private let bootstrapResource: RemotePhotoVolumeBootstrapResourceProtocol
    private let client: Client

    init(
        bootstrapResource: RemotePhotoVolumeBootstrapResourceProtocol,
        client: Client
    ) {
        self.bootstrapResource = bootstrapResource
        self.client = client
    }

    func getRemoteState() async throws -> RemotePhotosVolumeFetchResult {
        let volumes = try await client.getVolumes()
        if let remoteVolume = volumes.first(where: { $0.type == .photo && $0.state == .active }) {
            Log.info("Photo volume exists on remote, bootstrapping now.", domain: .albums)
            // Photo volume exists in remote, we can store it.
            return try await bootstrap(photoVolume: remoteVolume)
        } else {
            Log.info("Photo volume doesn't exists on remote.", domain: .albums)
            // Photo volume doesn't exist. We need to validate if old share exists or not.
            return .noPhotoShare
        }
    }

    private func bootstrap(photoVolume: PDClient.Volume) async throws -> RemotePhotosVolumeFetchResult {
        try await bootstrapResource.bootstrap(volume: photoVolume)
        return .photoVolume(photoVolume.volumeID)
    }
}
