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

public final class ArchivingFileCompressor: FileLogRotator {
    private let fileManager = FileManager.default
    private let archiveDirectory = PDFileManager.logsArchiveDirectory

    public init() { }

    public func rotate(_ file: URL) {
        processFile(file)
        processAllFilesInDirectory(inSource: file.deletingLastPathComponent())
    }

    private func processFile(_ file: URL) {
        let sourceURL = file
        let destinationURL = archiveDirectory.appendingPathComponent("\(file.lastPathComponent).lzfse")

        compressFile(sourceURL, to: destinationURL)
        deleteSourceFile(sourceURL)
    }

    private func processAllFilesInDirectory(inSource source: URL) {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            for fileURL in fileURLs where !fileURL.lastPathComponent.hasPrefix(".") {
                processFile(fileURL)
            }
        } catch {
            SentryClient.shared.record(level: .error, errorOrMessage: .right("LogCollectionError 😵🗂️. Failed to list files in directory: \(error)"))
        }
    }

    private func deleteSourceFile(_ file: URL) {
        do {
            try fileManager.removeItem(at: file)
        } catch {
            SentryClient.shared.record(level: .error, errorOrMessage: .right("LogCollectionError 😵🗂️. Failed to delete file: \(error)"))
        }
    }

    private func compressFile(_ source: URL, to destination: URL) {
        do {
            try Archiver.archive(source, to: destination)
        } catch {
            SentryClient.shared.record(level: .error, errorOrMessage: .right("LogCollectionError 😵🗂️. Failed to archive file: \(error)"))
        }
    }

    private func decompressFile(_ source: URL, to destination: URL) {
        do {
            try Archiver.unarchive(source, to: destination)
        } catch {
            SentryClient.shared.record(level: .error, errorOrMessage: .right("LogCollectionError 😵🗂️. Failed to unarchive file: \(error)"))
        }
    }
}
