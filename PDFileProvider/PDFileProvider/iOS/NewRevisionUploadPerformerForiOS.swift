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

import FileProvider
import PDCore
import CoreData

public final class NewRevisionUploadPerformerForiOS: NewRevisionUploadPerformer {

    public init() {}

    // swiftlint:disable:next function_parameter_count
    public func uploadNewRevision(item: NSFileProviderItem, file: File, tower: Tower, copy: URL, fileSize: Int, pendingFields: NSFileProviderItemFields, progress: Progress?, moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool) {
        if tower.localSettings.driveiOSSDKUploadMain, let sdkRevisionUploader = tower.sdkRevisionUploader {
            return try await uploadViaSDK(file: file, tower: tower, sdkRevisionUploader: sdkRevisionUploader, copy: copy, fileSize: fileSize, pendingFields: pendingFields, moc: moc)
        } else {
            return try await uploadViaLegacy(file: file, tower: tower, copy: copy, fileSize: fileSize, pendingFields: pendingFields)
        }
    }

    public func uploadViaSDK(file: File, tower: Tower, sdkRevisionUploader: SDKRevisionUploaderProtocol, copy: URL, fileSize: Int, pendingFields: NSFileProviderItemFields, moc: NSManagedObjectContext) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool) {
        await sdkRevisionUploader.cancel(file: file.identifier.any())
        let uploadedIdentifier = try await sdkRevisionUploader.upload(identifier: file.identifier.any(), fileUrl: copy)
        let file: CoreDataFile = try File.fetchOrThrow(identifier: uploadedIdentifier, in: moc)
        tower.forcePolling(volumeIDs: [file.identifier.volumeID])
        return (try NodeItem(node: file), pendingFields, false)
    }

    public func uploadViaLegacy(file: File, tower: Tower, copy: URL, fileSize: Int, pendingFields: NSFileProviderItemFields) async throws -> (NSFileProviderItem?, NSFileProviderItemFields, Bool) {
        if let uploadID = file.uploadIDIfUploadingNewRevision() {
            tower.fileUploader.cancelOperation(id: uploadID)
            file.prepareForNewUpload()
        }

        let fileWithNewRevision = try tower.revisionImporter.importNewRevision(from: copy, into: file)
        guard fileSize == copy.fileSize else {
            throw URLConsistencyError.urlSizeMismatch
        }

        // TODO: add progress reporting here, maybe by using SuspendableFileUploader instead of tower.fileUploader?
        let fileWithUploadedRevision = try await tower.fileUploader.upload(fileWithNewRevision)
        return (try NodeItem(node: fileWithUploadedRevision), pendingFields, false)
    }
}
