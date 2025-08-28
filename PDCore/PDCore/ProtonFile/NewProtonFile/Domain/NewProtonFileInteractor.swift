// Copyright (c) 2024 Proton AG
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

import PDClient

public struct NewProtonFileInput {
    let name: String
    let parentIdentifier: NodeIdentifier

    public init(name: String, parentIdentifier: NodeIdentifier) {
        self.name = name
        self.parentIdentifier = parentIdentifier
    }
}

public final class NewProtonFileInteractor: ThrowingAsynchronousInteractor {
    private let payloadFactory: NewProtonFilePayloadFactoryProtocol
    private let createDocumentRepository: NewProtonFileRepository
    private let metadataRepository: LinksMetadataRepository
    private let updateRepository: LinksUpdateRepository

    public init(
        payloadFactory: NewProtonFilePayloadFactoryProtocol,
        createDocumentRepository: NewProtonFileRepository,
        metadataRepository: LinksMetadataRepository,
        updateRepository: LinksUpdateRepository
    ) {
        self.payloadFactory = payloadFactory
        self.createDocumentRepository = createDocumentRepository
        self.metadataRepository = metadataRepository
        self.updateRepository = updateRepository
    }

    public func execute(with input: NewProtonFileInput) async throws -> NodeIdentifier {
        let parentIdentifier = input.parentIdentifier
        // Create document parameters
        let payload = try payloadFactory.makePayload(name: input.name, parentIdentifier: parentIdentifier)
        // Creates document in BE
        let createParameters = NewProtonFileParameters(shareId: parentIdentifier.shareID, payload: payload)
        let identifier = try await createDocumentRepository.create(with: createParameters)
        // Fetches file metadata
        let metadataParameters = LinksMetadataParameters(shareId: parentIdentifier.shareID, linkIds: [identifier.linkID])
        let metadataResponse = try await metadataRepository.getLinksMetadata(with: metadataParameters)
        // Inserts metadata to local DB
        try updateRepository.update(links: metadataResponse.sortedLinks, shareId: parentIdentifier.shareID)
        return NodeIdentifier(identifier.linkID, parentIdentifier.shareID, input.parentIdentifier.volumeID)
    }
}
