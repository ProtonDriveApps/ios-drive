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

import Foundation
// MARK: - List Photos Share
public protocol PhotoShareListing {
    func getPhotosDevice() async throws -> PhotosRoot
}

extension Client: PhotoShareListing {
    public func getPhotosDevice() async throws -> PhotosRoot {
        let response = try await listPhotoDevice()

        async let share = try bootstrapPhotosShare(shareID: response.share.shareID)
        async let root = try bootstrapPhotosRoot(shareID: response.share.shareID, nodeID: response.share.linkID)

        return try await PhotosRoot(link: root, share: share, device: response.device)
    }

    private func listPhotoDevice() async throws -> ListDevicesEndpoint.Response.ShareDevice {
        let endpoint = ListDevicesEndpoint(service: service, credential: try credential())
        let reponse = try await request(endpoint)

        guard let shareDevice = reponse.devices.first(where: { $0.device.type == 4 }) else {
            throw NSError(domain: "Volume has no Photos Device", code: 0)
        }

        return shareDevice
    }

    func bootstrapPhotosShare(shareID: String) async throws -> Share {
        let endpoint = ShareEndpoint(shareID: shareID, service: service, credential: try credential())
        return try await request(endpoint)
    }

    func bootstrapPhotosRoot(shareID: ShareID, nodeID: FolderID) async throws -> Link {
        let endpoint = LinkEndpoint(shareID: shareID, linkID: nodeID, service: self.service, credential: try credential())
        let response = try await request(endpoint)
        return response.link
    }
}

// MARK: - Create
public protocol PhotoShareCreator {
    func createPhotosShare(photoShare: NewPhotoShare) async throws -> CreateDeviceEndpoint.Response
}

extension Client: PhotoShareCreator {
    public func createPhotosShare(photoShare: NewPhotoShare) async throws -> CreateDeviceEndpoint.Response {
        let parameters = CreateDeviceEndpoint.Parameters(
            body: .init(
                device: .init(
                    volumeID: photoShare.volumeID,
                    syncState: .on,
                    type: .photos
                ),
                share: .init(
                    name: photoShare.shareName,
                    addressID: photoShare.addressID,
                    key: photoShare.shareKey,
                    passphrase: photoShare.sharePassphrase,
                    passphraseSignature: photoShare.sharePassphraseSignature
                ),
                link: .init(
                    nodeKey: photoShare.nodeKey,
                    nodePassphrase: photoShare.nodePassphrase,
                    nodePassphraseSignature: photoShare.nodePassphraseSignature,
                    nodeHashKey: photoShare.nodeHashKey,
                    name: photoShare.nodeName
                )
            )
        )

        let endpoint = try CreateDeviceEndpoint(parameters: parameters, service: service, credential: try credential())
        return try await request(endpoint)
    }
}

// MARK: - Delete Device
public protocol PhotoShareDeleting {
    func deletePhotosShare(deviceID: String) async throws
}

extension Client: PhotoShareDeleting {
    public func deletePhotosShare(deviceID: String) async throws {
        let endpoint = DeleteDeviceEndpoint(deviceID: deviceID, service: service, credential: try credential())
        _ = try await request(endpoint)
    }
}
