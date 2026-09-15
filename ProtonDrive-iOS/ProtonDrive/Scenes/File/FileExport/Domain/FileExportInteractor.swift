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
import PDSDKCore

struct DownloadedFile: Sendable {
    let url: URL
    let mimeType: MimeType
}

struct FileDownloadResult: Sendable {
    let downloaded: [DownloadedFile]
    /// Cancellations are not included.
    let failures: [FileExportError]
    let containsOnlyMedia: Bool

    var urls: [URL] { downloaded.map(\.url) }
    var successCount: Int { downloaded.count }
    var failureCount: Int { failures.count }
}

protocol FileExportInteractorProtocol {
    func downloadAll(_ files: [NodeDTO]) async -> FileDownloadResult
    func cancel(_ file: NodeDTO)
}

final class FileExportInteractor: FileExportInteractorProtocol {
    private let tower: Tower
    private var downloader: SDKFileDownloaderProtocol { tower.sdkObjects.fileDownloader }

    init(tower: Tower) {
        self.tower = tower
    }

    func downloadAll(_ files: [NodeDTO]) async -> FileDownloadResult {
        let outcomes = await withTaskGroup(of: DownloadOutcome.self) { group in
            for file in files {
                group.addTask { await self.download(file) }
            }
            return await group.reduce(into: [DownloadOutcome]()) { $0.append($1) }
        }

        var downloaded: [DownloadedFile] = []
        var failures: [FileExportError] = []
        for outcome in outcomes {
            switch outcome {
            case .downloaded(let file): downloaded.append(file)
            case .failed(let error): failures.append(error)
            case .cancelled: break
            }
        }
        return FileDownloadResult(
            downloaded: downloaded,
            failures: failures,
            containsOnlyMedia: files.allSatisfy { isPhotoOrVideo($0.mimeType) }
        )
    }

    func cancel(_ file: NodeDTO) {
        downloader.cancel(operationsOf: [file.id])
    }

    private func download(_ file: NodeDTO) async -> DownloadOutcome {
        do {
            let url = try await prepareForExport(file)
            return .downloaded(DownloadedFile(url: url, mimeType: MimeType(value: file.mimeType)))
        } catch let error as FileExportError {
            if case .cancelled = error {
                return .cancelled
            }
            Log.error("File download failed", error: error, domain: .downloader)
            return .failed(error)
        } catch {
            Log.error("File download failed", error: error, domain: .downloader)
            return .failed(.sdkError(error.localizedDescription))
        }
    }

    private func prepareForExport(_ file: NodeDTO) async throws -> URL {
        if !file.isDownloaded {
            try await downloadContent(of: file)
        }
        return try await filePath(of: file)
    }

    private func downloadContent(of file: NodeDTO) async throws {
        do {
            try await downloader.download(file: file.id)
        } catch {
            if let cancelError = error as? SDKDownloadErrors, cancelError == .cancelled {
                throw FileExportError.cancelled
            }
            Log.error("Download file failed", error: error, domain: .sdk)
            throw FileExportError.sdkError(error.localizedDescription)
        }
    }

    private func filePath(of file: NodeDTO) async throws -> URL {
        do {
            if DecryptedFileManager.validatedDecryptedFilePath(identifier: file.nodeIdentifier) == nil {
                let pool = tower.storage.backgroundContextPool
                let objectID = file.objectID
                try await pool.performInContext { context in
                    let coreDataFile: CoreDataFile = try context.typedObject(with: objectID)
                    try DecryptedFileManager.decryptLegacyBlocksInContextIfNeeded(file: coreDataFile)
                }
            }
            return try DecryptedFileManager.ensureHardLink(identifier: file.id, filename: file.name)
        } catch DecryptedFileManagerError.noDecryptedFile {
            Log.error("No local file after downloading", error: nil, domain: .downloader)
            throw FileExportError.notLocalAvailable
        } catch {
            Log.error("Make hard link failed", error: error, domain: .downloader)
            throw FileExportError.linkFailed(error.localizedDescription)
        }
    }

    private func isPhotoOrVideo(_ mimeType: String) -> Bool {
        let mime = MimeType(value: mimeType)
        return mime.isImage || mime.isVideo
    }
}

private enum DownloadOutcome: Sendable {
    case downloaded(DownloadedFile)
    case failed(FileExportError)
    case cancelled
}
