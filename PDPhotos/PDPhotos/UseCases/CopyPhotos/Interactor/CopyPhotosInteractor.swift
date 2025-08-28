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
import PDCoreIOS

protocol CopyPhotosInteractorProtocol {
    func execute(parameters: CopyPhotosInteractor.Parameters) async throws -> CopyPhotosOutput
}

final class CopyPhotosInteractor: CopyPhotosInteractorProtocol {
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(parameters: Parameters) async throws -> CopyPhotosOutput {
        let filteredIds = try await getFilteredIds(parameters: parameters)
        let duplicatesCount = parameters.primaryIds.count - filteredIds.count

        guard !filteredIds.isEmpty else {
            return CopyPhotosOutput(duplicatesCount: duplicatesCount, initialCount: 0, targetParentId: parameters.targetParentId, result: .allSuccess([]))
        }

        let (photoProperties, failedIDs) = await fetchPhotos(photoIDs: filteredIds)
        let albumProperty = try await dependencies.albumReader.getDecryptedProperties(
            from: parameters.targetParentId,
            in: dependencies.context
        )

        let requestParameters = try makeRequestParameters(
            albumProperty: albumProperty,
            photoProperties: photoProperties,
            targetParentLinkID: parameters.targetParentId.id,
            targetVolumeID: parameters.targetParentId.volumeID
        )
        let result = await copyNodes(hasReadFailed: !failedIDs.isEmpty, parameters: requestParameters)
        let output = CopyPhotosOutput(duplicatesCount: duplicatesCount, initialCount: filteredIds.count, targetParentId: parameters.targetParentId, result: result)
        Log.debug(output.description, domain: .albums)
        return output
    }

    private func getFilteredIds(parameters: Parameters) async throws -> Set<AnyVolumeIdentifier> {
        if parameters.copyToPhotoRoot {
            let filteredIds = try await dependencies.duplicateCheckRepository.filterAgainstPhotoRoot(photoIdentifiers: parameters.primaryIds)
            return filteredIds
        } else {
            let filteredIds = try await dependencies.duplicateCheckRepository.filterAgainstAlbum(
                albumId: parameters.targetParentId,
                photoIdentifiers: parameters.primaryIds
            )
            return filteredIds
        }
    }

    private func copyNodes(hasReadFailed: Bool, parameters: [CopyLinkToVolumeEndpoint.Parameters]) async -> CopyPhotosOutput.Result {
        let client = dependencies.client
        let (newLinkIDs, errors) = await withTaskGroup(
            of: Swift.Result<String, Error>.self,
            returning: ([String], [Error]).self
        ) { group in
            for parameter in parameters {
                group.addTask {
                    do {
                        let linkID = try await client.copyLinkToVolume(parameters: parameter)
                        return .success(linkID)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var linkIDs: [String] = []
            var errors: [Error] = []
            for await result in group {
                switch result {
                case .success(let linkID):
                    linkIDs.append(linkID)
                case .failure(let error):
                    errors.append(error)
                }
            }
            return (linkIDs, errors)
        }

        if !newLinkIDs.isEmpty {
            if hasReadFailed {
                return .partialSuccess(newLinkIDs, errors.first)
            } else {
                return .allSuccess(newLinkIDs)
            }
        } else {
            return .failure(errors.first)
        }
    }
}

// MARK: - Prepare photo data
extension CopyPhotosInteractor {
    private func fetchPhotos(photoIDs: Set<PhotoId>) async -> ([[PhotoProperty]], Set<PhotoId>) {
        let context = dependencies.context
        let reader = dependencies.photoReader
        var failedIDs: Set<PhotoId> = []
        return await context.perform {
            var properties: [[PhotoProperty]] = []
            for photoID in photoIDs {
                guard let property = try? reader.getDecryptedProperties(from: photoID, in: context) else {
                    failedIDs.insert(photoID)
                    continue
                }
                properties.append(property)
            }
            return (properties, failedIDs)
        }
    }
}

// MARK: - Prepare request parameters
extension CopyPhotosInteractor {
    private func makeRequestParameters(
        albumProperty: NodeWithNodeHashKeyProperty,
        photoProperties: [[PhotoProperty]],
        targetParentLinkID: Link.LinkID,
        targetVolumeID: String
    ) throws -> [CopyLinkToVolumeEndpoint.Parameters] {
        var parameters: [CopyLinkToVolumeEndpoint.Parameters] = []
        let signersKit = try dependencies.signersKitFactory.make(forSigner: .main)
        for photoProperty in photoProperties {
            guard let mainPhotoProperty = photoProperty.first else { continue }
            let photos = try makeRequestPhotos(
                albumProperty: albumProperty,
                photoProperty: photoProperty,
                signersKit: signersKit
            )
            let parameter = try makeRequestParameter(
                albumProperty: albumProperty,
                mainPhotoProperty: mainPhotoProperty,
                targetParentLinkID: targetParentLinkID,
                targetVolumeID: targetVolumeID,
                photos: photos,
                signersKit: signersKit
            )
            parameters.append(parameter)
        }
        return parameters
    }

    private func makeRequestParameter(
        albumProperty: NodeWithNodeHashKeyProperty,
        mainPhotoProperty: PhotoProperty,
        targetParentLinkID: Link.LinkID,
        targetVolumeID: String,
        photos: CopyLinkToVolumeEndpoint.Photos?,
        signersKit: SignersKit
    ) throws -> CopyLinkToVolumeEndpoint.Parameters {
        let passphrase = try reEncryptPassphrase(albumNodeKey: albumProperty.nodeKey, property: mainPhotoProperty)
        let encryptResult = try reEncryptPhotoName(
            albumProperty: albumProperty,
            photoProperty: mainPhotoProperty,
            signersKit: signersKit
        )
        return .init(
            volumeID: mainPhotoProperty.photoID.volumeID,
            linkID: mainPhotoProperty.photoID.id,
            body: .init(
                name: encryptResult.encryptedName,
                nodePassphrase: passphrase,
                hash: encryptResult.nameHash,
                targetVolumeID: targetVolumeID,
                targetParentLinkID: targetParentLinkID,
                nameSignatureEmail: encryptResult.signatureEmail,
                nodePassphraseSignature: nil,
                signatureEmail: nil,
                photos: photos
            )
        )
    }

    /// Make `Photos` in request body
    /// - Parameters:
    ///   - photoProperty: Properties of a photo set, it's [main photo property, ...related photo properties]
    private func makeRequestPhotos(
        albumProperty: NodeWithNodeHashKeyProperty,
        photoProperty: [PhotoProperty],
        signersKit: SignersKit
    ) throws -> CopyLinkToVolumeEndpoint.Photos? {
        guard let mainProperty = photoProperty.first else { return nil }
        let relatedPhotoProperties = photoProperty.dropFirst()
        let hashKey = albumProperty.decryptedHashKey
        var relatedPhotos: [CopyLinkToVolumeEndpoint.RelatedPhoto] = []
        for property in relatedPhotoProperties {
            let result = try reEncryptPhotoName(
                albumProperty: albumProperty,
                photoProperty: property,
                signersKit: signersKit
            )
            let passphrase = try reEncryptPassphrase(albumNodeKey: albumProperty.nodeKey, property: property)
            let contentHash = try rehashed(contentDigest: property.contentHashDigest, albumDecryptedHashKey: hashKey)
            relatedPhotos.append(
                .init(
                    linkID: property.photoID.id,
                    name: result.encryptedName,
                    nodePassphrase: passphrase,
                    hash: result.nameHash,
                    contentHash: contentHash
                )
            )
        }

        let mainContentHash = try rehashed(contentDigest: mainProperty.contentHashDigest, albumDecryptedHashKey: hashKey)
        return .init(
            contentHash: mainContentHash,
            relatedPhotos: relatedPhotos
        )
    }

    private func reEncryptPassphrase(albumNodeKey: String, property: PhotoProperty) throws -> String {
        try dependencies.encryptor.reencryptKeyPacket(
            of: property.passphrase,
            oldParentKey: property.parentKey,
            oldParentPassphrase: property.decryptedParentPassphrase,
            newParentKey: albumNodeKey
        )
    }

    private func reEncryptPhotoName(
        albumProperty: NodeWithNodeHashKeyProperty,
        photoProperty: PhotoProperty,
        signersKit: SignersKit
    ) throws -> NameEncryptor.Result {
        let nameEncryptor = NameEncryptor(
            dependencies: .init(
                encryptor: dependencies.encryptor,
                signersKit: signersKit
            )
        )
        return try nameEncryptor.encrypt(
            parameters: .init(
                name: photoProperty.decryptedName,
                nodeKey: albumProperty.nodeKey,
                decryptedHashKey: albumProperty.decryptedHashKey
            )
        )
    }

    private func rehashed(contentDigest: FileContentDigest, albumDecryptedHashKey: String) throws -> String {
        switch contentDigest {
        case .contentDigest(let digest):
            return try dependencies.encryptor.makeHmac(string: digest, hashKey: albumDecryptedHashKey)
        case .contentHash(let string):
            return string
        }
    }
}

extension CopyPhotosInteractor {
    struct Dependencies {
        let albumReader: DecryptedNodeHashKeyRepository
        let client: CopyRepository
        let context: NSManagedObjectContext
        let encryptor: EncryptionResource
        let photoReader: PhotoReaderProtocol
        let signersKitFactory: SignersKitFactoryProtocol
        let duplicateCheckRepository: PhotosDuplicateCheckRepository
    }

    struct Parameters {
        let primaryIds: Set<PhotoId>
        let targetParentId: AnyVolumeIdentifier
        let copyToPhotoRoot: Bool
    }

    enum CopyError: Error {
        case nameEncryptionResultNotFound
    }
}

struct CopyPhotosOutput {
    let duplicatesCount: Int
    let initialCount: Int
    let targetParentId: AnyVolumeIdentifier
    let result: Result

    enum Result {
        case allSuccess([String])
        /// Success num, error
        case partialSuccess([String], Error?)
        case failure(Error?)
    }

    enum CopyError: Error {
        case nameEncryptionResultNotFound
    }

    var description: String {
        var successNum: Int = 0
        switch result {
        case .allSuccess(let ids):
            successNum = ids.count
        case .partialSuccess(let ids, _):
            successNum = ids.count
        case .failure:
            break
        }
        return [
            "Copy \(initialCount) photos to album: \(targetParentId)",
            "duplication: \(duplicatesCount)",
            "success: \(successNum)"
        ].joined(separator: "\n")
    }
}
