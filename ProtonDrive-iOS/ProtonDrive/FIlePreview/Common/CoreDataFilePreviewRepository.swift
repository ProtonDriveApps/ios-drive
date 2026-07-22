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

import Foundation
import CoreData
import PDCore
import UIKit

final class CoreDataFilePreviewRepository: FilePreviewRepository {
    private let context: NSManagedObjectContext
    private let file: File

    @ThreadSafe private var cleartextUrl: URL?
    private let cancellation = LegacyDecryptionCancellation()

    init(context: NSManagedObjectContext, file: File) {
        self.context = context
        self.file = file
    }
    
    func getURL() -> URL {
        if let cleartextUrl = cleartextUrl, FileManager.default.fileExists(atPath: cleartextUrl.path) {
            return cleartextUrl
        } else {
            Log.error(error: DriveError("The file was not found."), domain: .fileManager)
            return URL.blank
        }
    }

    func requiresDecryption() async throws -> Bool {
        if DecryptedFileManager.validatedDecryptedFilePath(identifier: file.identifier) != nil {
            cleartextUrl = try DecryptedFileManager.ensureHardLink(
                identifier: file.genericIdentifier,
                filename: file.decryptedName
            )
            return false
        } else {
            return true
        }
    }

    func loadFile() async throws {
        cancellation.isCancelled = false
        do {
            try await DecryptedFileManager.decryptLegacyBlocksIfNeeded(
                file: file,
                cancellation: cancellation
            )
        } catch Revision.Errors.cancelled {
            cleartextUrl = nil
            throw CancellationError()
        }
        if cancellation.isCancelled {
            cleartextUrl = nil
            throw CancellationError()
        }
        cleartextUrl = try DecryptedFileManager.ensureHardLink(
            identifier: file.genericIdentifier,
            filename: file.decryptedName
        )
    }

    func getFileMetadata() async -> (AnyVolumeIdentifier, MimeType) {
        await context.perform { [context] in
            let file = self.file.in(moc: context)
            let id = file.identifierWithinManagedObjectContext.any()
            let mimeType = MimeType(value: file.mimeType)
            return (id, mimeType)
        }
    }

    deinit {
        cancel()
    }
}

extension CoreDataFilePreviewRepository {
    func cancel() {
        cancellation.isCancelled = true
    }
}
