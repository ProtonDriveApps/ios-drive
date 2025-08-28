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
    func getPhotosRoot() async throws -> PhotosRoot
    func getPhotosRoot(listing: ShareListing) async throws -> PhotosRoot
    func getActivePhotoShares() async throws -> [ShareListing]
}

extension Client: PhotoShareListing {
    public func getPhotosRoot() async throws -> PhotosRoot {
        let response = try await listPhotoShares()
        return try await getPhotosRoot(listing: response)
    }

    public func getPhotosRoot(listing: ShareListing) async throws -> PhotosRoot {
        async let share = try bootstrapPhotosShare(shareID: listing.shareID)
        async let root = try bootstrapPhotosRoot(shareID: listing.shareID, nodeID: listing.linkID, breadcrumbs: .startCollecting())
        return try await PhotosRoot(link: root, share: share)
    }

    public func listPhotoShares() async throws -> ShareListing {
        let shares = try await getActivePhotoShares()
        guard let share = shares.first else {
            throw NSError(domain: "No Photos Share found", code: 0)
        }
        return share
    }

    public func getActivePhotoShares() async throws -> [ShareListing] {
        let parameters = ListSharesEndpoint.Parameters(shareType: .photos, showAll: .default)
        let endpoint = ListSharesEndpoint(parameters: parameters, service: service, credential: try credential())
        let response = try await request(endpoint)
        return response.shares.filter { $0.state == .active && $0.locked != true }
    }

    func bootstrapPhotosShare(shareID: String) async throws -> Share {
        let endpoint = ShareEndpoint(shareID: shareID, service: service, credential: try credential())
        return try await request(endpoint)
    }

    func bootstrapPhotosRoot(shareID: ShareID, nodeID: FolderID, breadcrumbs: Breadcrumbs) async throws -> Link {
        let endpoint = try LinkEndpoint(shareID: shareID, linkID: nodeID, service: self.service, credential: try credential(),
                                        breadcrumbs: breadcrumbs.collect())
        let response = try await request(endpoint)
        return response.link
    }
}

// MARK: - Create
public protocol PhotoShareCreator {
    func createPhotosShare(photoShare: NewPhotoShare) async throws -> CreatePhotosShareEndpoint.Response
}

extension Client: PhotoShareCreator {
    public func createPhotosShare(photoShare: NewPhotoShare) async throws -> CreatePhotosShareEndpoint.Response {
        let parameters = CreatePhotosShareEndpoint.Parameters(
            volumeId: photoShare.volumeID,
            body: .init(
                share: .init(
                    addressID: photoShare.addressID,
                    addressKeyID: photoShare.addressKeyID,
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

        let endpoint = try CreatePhotosShareEndpoint(parameters: parameters, service: service, credential: try credential())
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
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

// MARK: - Listing

extension Client: PhotosListing {
    public func getPhotosList(with parameters: PhotosListRequestParameters) async throws -> PhotosListResponse {
        let endpoint = PhotosListEndpoint(service: service, credential: try credential(), parameters: parameters)
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
    }
}

extension Client: PhotosDuplicatesRepository {
    public func getPhotosDuplicates(with parameters: FindDuplicatesParameters) async throws -> FindDuplicatesResponse {
        let endpoint = FindDuplicatesEndpoint(parameters: parameters, service: service, credential: try credential())
        return try await request(endpoint, completionExecutor: .asyncExecutor(dispatchQueue: backgroundQueue))
    }
}

// MARK: - TagMigration
public protocol TagsMigrationAPIClient {
    func getTagsMigrationState(volumeID: String) async throws -> TagsMigrationState
    func setTagsMigrationState(volumeID: String, request: TagsMigrationStateRequest) async throws
}

extension Client: TagsMigrationAPIClient {
    public func getTagsMigrationState(volumeID: String) async throws -> TagsMigrationState {
        let endpoint = GetTagsMigrationStateEndpoint(volumeID: volumeID, service: service, credential: try credential())
        return try await request(endpoint).toDomain()
    }

    public func setTagsMigrationState(volumeID: String, request requestBody: TagsMigrationStateRequest) async throws {
        let endpoint = SetTagsMigrationStateEndpoint(volumeID: volumeID, requestBody: requestBody, service: service, credential: try credential())
        _ = try await request(endpoint)
    }
}

extension GetTagsMigrationStateEndpoint.TagsMigrationStateResponse {
    func toDomain() -> TagsMigrationState {
        TagsMigrationState(
            isFinished: self.finished,
            anchor: anchor.map { response in
                TagsMigrationState.Anchor(
                    lastProcessedLinkID: response.lastProcessedLinkID,
                    lastProcessedCaptureTime: Date(timeIntervalSince1970: TimeInterval(response.lastProcessedCaptureTime)),
                    lastMigrationTimestamp: Date(timeIntervalSince1970: TimeInterval(response.lastMigrationTimestamp)),
                    lastClientUID: response.lastClientUID
                )
            }
        )
    }
}
