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
import PDCore

protocol UpdateAlbumInteractorProtocol {
    func execute(parameters: UpdateAlbumParameters) async throws
}

struct UpdateAlbumInteractor: UpdateAlbumInteractorProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(parameters: UpdateAlbumParameters) async throws {
        let isCoverChanged = parameters.coverLinkID != nil
        let isNameChanged = parameters.newAlbumName != nil

        guard isCoverChanged || isNameChanged else {
            return
        }

        let requestParameters = try await makeRequestParameters(from: parameters)
        try await dependencies.client.updateAlbum(parameter: requestParameters)
        try await updateCoreDataAlbum(parameters: parameters, requestParameter: requestParameters)
    }

    private func makeRequestParameters(from parameters: UpdateAlbumParameters) async throws -> UpdateAlbumRequest.Parameters {
        let link = try await dependencies.requestFactory.makeRequestLink(parameters: parameters)
        return UpdateAlbumRequest.Parameters(
            volumeID: parameters.albumID.volumeID,
            linkID: parameters.albumID.id,
            body: .init(
                coverLinkID: parameters.coverLinkID,
                link: link
            )
        )
    }

    private func updateCoreDataAlbum(
        parameters: UpdateAlbumParameters,
        requestParameter: UpdateAlbumRequest.Parameters
    ) async throws {
        let context = dependencies.managedObjectContext
        let albumID = parameters.albumID
        let volumeID = albumID.volumeID
        try await context.perform {
            guard let album = CoreDataAlbum.fetch(identifier: albumID, in: context) else {
                throw Error.missingAlbum
            }

            let isCoverChanged = parameters.coverLinkID != nil

            if isCoverChanged {
                if let coverLinkID = requestParameter.body.coverLinkID {
                    album.coverPhoto = CoreDataPhoto.fetch(id: coverLinkID, volumeID: volumeID, in: context)
                    album.coverLinkID = coverLinkID
                    album.albumListing?.coverLinkID = coverLinkID
                } else {
                    album.coverPhoto = nil
                    album.coverLinkID = nil
                    album.albumListing?.coverLinkID = nil
                }
            }

            if let link = requestParameter.body.link {
                album.name = link.name
                album.signatureEmail = link.nameSignatureEmail
                album.nodeHash = link.hash
            }
            try context.save()
        }
    }
}

extension UpdateAlbumInteractor {
    struct Dependencies {
        let client: AlbumAPIService
        let managedObjectContext: NSManagedObjectContext
        let photoRootInfoProvider: PhotoRootInfoProviderProtocol
        let signersKitFactory: SignersKitFactoryProtocol
        let requestFactory: UpdateAlbumRequestFactoryProtocol
    }

    enum Error: LocalizedError {
        case missingOriginalHash
        case missingAlbum
    }
}

struct UpdateAlbumParameters {
    let albumID: AnyVolumeIdentifier
    // Nil if not change
    let coverLinkID: String?
    let newAlbumName: String?
    let originalHash: String?
}
