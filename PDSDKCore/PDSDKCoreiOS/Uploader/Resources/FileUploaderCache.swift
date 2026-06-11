// Copyright (c) 2026 Proton AG
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
import PDSDKCore
import ProtonDriveSDK
@preconcurrency import PDCore

struct UploadFileInput {
    let fileAttributes: FileAttributes
    let identifier: AnyVolumeIdentifier
    let parentIdentifier: SDKNodeUid
    let resourceURL: URL
    let shareID: String
    let uploadID: UUID
    var filename: String { resourceURL.lastPathComponent }
    var mimeType: String { resourceURL.mimeType() }
}

protocol FileUploaderCacheProtocol: Sendable {
    func getUploadInput(from identifier: AnyVolumeIdentifier) async throws -> UploadFileInput
    func updateState(for identifier: AnyVolumeIdentifier, to newState: Node.State) async throws
    func deleteTemp(identifier: AnyVolumeIdentifier) async
    func get(properties: [PartialKeyPath<CoreDataFile>], from identifier: AnyVolumeIdentifier) async throws -> [Any]
    func getPhotoCloudIdentifier(for identifier: AnyVolumeIdentifier) async -> String?
    func getPhotoUploadInput(from identifier: AnyVolumeIdentifier) async throws -> PhotoAttributes
}

/// Read/write state for files being uploaded
struct FileUploaderCache: FileUploaderCacheProtocol {
    private let encoder: JSONEncoder
    private let managedObjectContext: NSManagedObjectContext

    init(encoder: JSONEncoder, managedObjectContext: NSManagedObjectContext) {
        self.encoder = encoder
        self.managedObjectContext = managedObjectContext
    }

    func getUploadInput(from identifier: AnyVolumeIdentifier) async throws -> UploadFileInput {
        try await managedObjectContext.perform { [managedObjectContext] in
            let file: CoreDataFile = try CoreDataFile
                .fetchOrThrow(identifier: identifier, allowSubclasses: true, in: managedObjectContext)

            let parentIdentifier = try file.parentSDKNodeUidWithinContext()
            guard let resourceURL = file.activeRevisionDraft?.normalizedUploadableResourceURL else {
                throw SDKUploadErrors.missingResourceURL
            }
            guard FileManager.default.fileExists(atPath: resourceURL.path) else {
                throw SDKUploadErrors.missingFile
            }
            guard file.nameSignatureEmail != nil else {
                throw SDKUploadErrors.invalidFileData
            }
            guard let state = file.state, ![.active, .deleted, .deleting].contains(state) else {
                throw SDKUploadErrors.fileAlreadyUploaded
            }
            guard let uploadID = file.uploadID else { throw SDKUploadErrors.noUploadID }
            let shareID = file.shareID

            // Get file attributes
            let attributes = try FileManager.default.attributesOfItem(atPath: resourceURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let creationDate = attributes[.creationDate] as? Date ?? Date.now
            let modificationDate = attributes[.modificationDate] as? Date ?? Date.now
            let fileAttributes = FileAttributes(fileSize: fileSize, creationDate: creationDate, modificationDate: modificationDate)

            return UploadFileInput(
                fileAttributes: fileAttributes,
                identifier: identifier,
                parentIdentifier: parentIdentifier,
                resourceURL: resourceURL,
                shareID: shareID,
                uploadID: uploadID
            )
        }
    }

    func updateState(for identifier: AnyVolumeIdentifier, to newState: Node.State) async throws {
        try await managedObjectContext.perform {
            let file: CoreDataFile = try CoreDataFile
                .fetchOrThrow(identifier: identifier, allowSubclasses: true, in: managedObjectContext)
            file.state = newState

            if newState == .uploading, let photo = file as? CoreDataPhoto {
                photo.isUploading = true
            }
            try managedObjectContext.saveIfNeeded()
        }
    }

    func deleteTemp(identifier: AnyVolumeIdentifier) async {
        await managedObjectContext.perform { [managedObjectContext] in
            guard
                let file: CoreDataFile = try? CoreDataFile
                    .fetchOrThrow(identifier: identifier, allowSubclasses: true, in: managedObjectContext)
            else { return }
            managedObjectContext.delete(file)
            try? managedObjectContext.saveIfNeeded()
        }
    }

    func get(properties: [PartialKeyPath<CoreDataFile>], from identifier: AnyVolumeIdentifier) async throws -> [Any] {
        try await managedObjectContext.perform { [managedObjectContext] in
            let file: CoreDataFile = try CoreDataFile
                .fetchOrThrow(identifier: identifier, allowSubclasses: true, in: managedObjectContext)
            return properties.map { file[keyPath: $0] }
        }
    }

    private func additionalMetadata(from extendedAttributes: TemporalMetadata) throws -> [AdditionalMetadata] {
        var metadata: [AdditionalMetadata] = []
        // SDK handles `Common`, ignore it 
        if let location = extendedAttributes.location {
            let data = try encoder.encode(location)
            metadata.append(AdditionalMetadata(name: location.fieldName, utf8JsonValue: data))
        }

        if let camera = extendedAttributes.camera {
            let data = try encoder.encode(camera)
            metadata.append(AdditionalMetadata(name: camera.fieldName, utf8JsonValue: data))
        }

        let media = extendedAttributes.media
        let mediaData = try encoder.encode(media)
        metadata.append(AdditionalMetadata(name: media.fieldName, utf8JsonValue: mediaData))

        let iOSPhotos = extendedAttributes.iOSPhotos
        let iOSPhotosData = try encoder.encode(iOSPhotos)
        metadata.append(AdditionalMetadata(name: iOSPhotos.fieldName, utf8JsonValue: iOSPhotosData))

        return metadata
    }
}

// MARK: - Only for photo
extension FileUploaderCache {

    func getPhotoCloudIdentifier(for identifier: AnyVolumeIdentifier) async -> String? {
        await managedObjectContext.perform { [managedObjectContext] in
            guard let photo: CoreDataPhoto = try? CoreDataPhoto.fetchOrThrow(identifier: identifier, in: managedObjectContext) else {
                return nil
            }
            guard let tempMetadata = photo.tempBase64Metadata,
                  let extendedAttributes = TemporalMetadata(base64String: tempMetadata) else {
                return nil
            }
            return extendedAttributes.iOSPhotos.iCloudID
        }
    }

    func getPhotoUploadInput(from identifier: AnyVolumeIdentifier) async throws -> PhotoAttributes {
        try await managedObjectContext.perform { [managedObjectContext] in
            let photo: CoreDataPhoto = try CoreDataPhoto.fetchOrThrow(identifier: identifier, in: managedObjectContext)

            guard let resourceURL = photo.activeRevisionDraft?.normalizedUploadableResourceURL else {
                throw SDKUploadErrors.missingResourceURL
            }
            guard FileManager.default.fileExists(atPath: resourceURL.path) else {
                throw SDKUploadErrors.missingFile
            }
            guard photo.nameSignatureEmail != nil else {
                throw SDKUploadErrors.invalidFileData
            }
            guard let state = photo.state, ![.active, .deleted, .deleting].contains(state) else {
                throw SDKUploadErrors.fileAlreadyUploaded
            }
            guard let uploadID = photo.uploadID else { throw SDKUploadErrors.noUploadID }
            guard
                let tempMetadata = photo.tempBase64Metadata,
                let extendedAttributes = TemporalMetadata(base64String: tempMetadata)
            else { throw SDKUploadErrors.invalidFileData }
            let additionalMetadata = try additionalMetadata(from: extendedAttributes)
            guard
                let photoRootID: AnyVolumeIdentifier = photo.parentNode?.identifier.any(),
                let cloudIdentifier = extendedAttributes.iOSPhotos.iCloudID
            else {
                throw SDKUploadErrors.invalidFileData
            }
            guard let urlSize = resourceURL.fileSize else { throw SDKUploadErrors.invalidFileData }
            if photo.size != urlSize {
                let delta = photo.size - urlSize
                let context = LogContext(delta.description, forKey: "sizeDelta")
                Log.error("CoreDataPhoto size doesn't match disk size", error: nil, domain: .sdk, context: context)
                photo.size = urlSize
                try managedObjectContext.saveIfNeeded()
            }

            return PhotoAttributes(
                additionalMetadata: additionalMetadata,
                captureTime: photo.captureTime,
                childrenCount: photo.children.count,
                cloudIdentifier: cloudIdentifier,
                fileSize: Int64(urlSize),
                fileURL: resourceURL,
                identifier: identifier,
                mainPhotoUid: photo.parent?.identifier.any().sdkUid,
                mediaType: photo.mimeType,
                modificationDate: photo.modifiedDate,
                name: photo.decryptedName,
                parentFolderIdentifier: photoRootID.sdkUid,
                tags: photo.tags ?? [],
                uploadID: uploadID
            )
        }
    }
}
