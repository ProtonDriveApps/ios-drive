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

import Foundation
import PDCore
import Combine

final class FileExportViewModel {
    private let file: CoreDataFile
    private let tower: Tower
    
    init(file: CoreDataFile, tower: Tower) {
        self.file = file
        self.tower = tower
    }
    
    func shouldDownload() async throws -> Bool {
        let objectID = file.objectID
        return try await tower.storage.backgroundContextPool.performInContext { context in
            do {
                let existingFile: CoreDataFile = try context.typedObject(with: objectID)
                guard let revision = existingFile.activeRevision else {
                    Log.error("Missing active revision", error: nil, domain: .downloader)
                    throw FileExportError.missingActiveRevision
                }
                return !revision.isAvailableLocally()
            } catch {
                throw FileExportError.missingFile
            }
        }
    }

    func cancel() {
        let id = file.genericIdentifier
        if let downloader = tower.getSdkFileDownloader() {
            downloader.cancel(operationsOf: [id])
        }
        tower.downloader.cancel(operationsOf: [id])
    }
    
    func download() async throws {
        if let sdkFileDownloader = tower.getSdkFileDownloader() {
            let id = file.genericIdentifier
            do {
                try await sdkFileDownloader.download(file: id)
            } catch {
                if let cancelError = error as? SDKDownloadErrors, cancelError == .cancelled {
                    throw FileExportError.cancelled
                } else {
                    Log.error("Download file failed", error: error, domain: .sdk)
                    throw FileExportError.sdkError(error.localizedDescription)
                }
            }
        } else {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                guard let self else { return }
                tower.downloader.scheduleDownloadWithBackgroundSupport(cypherdataFor: file) { [weak self, weak file] result in
                    guard let self, let file else {
                        continuation.resume(throwing: FileExportError.cancelled)
                        return
                    }
                    switch result {
                    case .success:
                        continuation.resume(returning: ())
                    case .failure(let failure):
                        Log.error("Download file via legacy failed", error: failure, domain: .downloader)
                        continuation.resume(throwing: FileExportError.legacyError(failure.localizedDescription))
                    }
                }
            }
            await decryptLegacyDownloadIfNeeded(file: file)
        }
    }
    
    private func decryptLegacyDownloadIfNeeded(file: CoreDataFile) async {
        let objectID = file.objectID
        await tower.storage.backgroundContextPool.performInContext { context in
            guard let existingFile: CoreDataFile = try? context.typedObject(with: objectID) else { return }
            do {
                _ = try existingFile.activeRevision?.decryptFile()
            } catch {
                Log.error("Decrypt file failed", error: error, domain: .downloader)
            }
        }
    }
    
    func filePath() throws -> URL {
        let identifier = file.volumeBasedIdentifier
        guard let path = DecryptedFileManager.validatedDecryptedFilePath(identifier: identifier) else {
            Log.error("No local file after downloading", error: nil, domain: .downloader)
            throw FileExportError.notLocalAvailable
        }
        do {
            let filePath = try path.hardLink(filename: file.decryptedName)
            return filePath
        } catch {
            Log.error("Make hard link failed", error: error, domain: .downloader)
            throw FileExportError.linkFailed(error.localizedDescription)
        }
    }
}

enum FileExportError: Error, LocalizedError {
    case missingFile
    case missingActiveRevision
    case sdkError(String)
    case legacyError(String)
    case notLocalAvailable
    case linkFailed(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "Missing file"
        case .missingActiveRevision:
            return "Missing active revision"
        case .sdkError(let string):
            return "Download failed: \(string)"
        case .legacyError(let string):
            return "Downloaded failed: \(string)"
        case .notLocalAvailable:
            return "Downloaded file is not available"
        case .linkFailed(let string):
            return "Path generation error: \(string)"
        case .cancelled:
            return "Cancelled"
        }
    }
}
