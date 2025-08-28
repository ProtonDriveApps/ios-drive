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

import CoreData
import PDClient
import PDCore

protocol RemotePhotoVolumeBootstrapResourceProtocol {
    func bootstrap(volume: PDClient.Volume) async throws
}

final class RemotePhotoVolumeBootstrapResource: RemotePhotoVolumeBootstrapResourceProtocol {
    private let sharesListing: SharesListing
    private let bootstrapClient: BootstrapRootClient
    private let managedObjectContext: NSManagedObjectContext
    private let storageManager: StorageManager

    init(sharesListing: SharesListing, bootstrapClient: BootstrapRootClient, managedObjectContext: NSManagedObjectContext, storageManager: StorageManager) {
        self.sharesListing = sharesListing
        self.bootstrapClient = bootstrapClient
        self.managedObjectContext = managedObjectContext
        self.storageManager = storageManager
    }

    func bootstrap(volume: PDClient.Volume) async throws {
        let remoteShare = try await fetchRemoteShare(volumeId: volume.volumeID)
        let root = try await bootstrapClient.bootstrapRoot(shareID: remoteShare.shareID, rootLinkID: remoteShare.linkID)
        try await managedObjectContext.perform {
            let localVolume = Volume.fetchOrCreate(id: volume.volumeID, in: self.managedObjectContext)
            localVolume.fulfillVolume(with: volume)
            self.storageManager.updateShare(root.share, in: self.managedObjectContext)
            self.storageManager.updateLink(root.link, using: self.managedObjectContext)
            try self.managedObjectContext.saveOrRollback()
        }
    }

    private func fetchRemoteShare(volumeId: VolumeID) async throws -> ListSharesEndpoint.Response.Share {
        let parameters = ListSharesEndpoint.Parameters(shareType: .photos, showAll: .default)
        return try await sharesListing.listShares(parameters: parameters).first(where: {
            $0.volumeID == volumeId
        }) ?! "Missing remote share"
    }
}
