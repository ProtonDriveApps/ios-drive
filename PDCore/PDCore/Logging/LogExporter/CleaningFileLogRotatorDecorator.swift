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

public final class CleaningFileLogRotatorDecorator: FileLogRotator {
    private let rotator: FileLogRotator
    private let archiveDirectory = PDFileManager.logsArchiveDirectory
    private let dateProvider: () -> Date
    private let fileManager = FileManager.default

    public let maximumArchiveSize: Int

    public init(
        maximumArchiveSize: Int,
        rotator: FileLogRotator,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.maximumArchiveSize = maximumArchiveSize
        self.rotator = rotator
        self.dateProvider = dateProvider
    }

    public func rotate(_ file: URL) {
        deleteOlderThanSevenDaysFiles()
        pruneFilesToMaintainDirectorySizeLimit()
        rotator.rotate(file)
    }

    /// Delete files older than 7 days
    private func deleteOlderThanSevenDaysFiles() {
        do {
            let sevenDaysAgo = dateProvider().addingTimeInterval(-7 * 24 * 60 * 60)
            let oldFiles = try getAllArchivedFiles().filter { $0.lastModificationDate < sevenDaysAgo }
            for oldFile in oldFiles {
                try fileManager.removeItem(at: oldFile)
            }
        } catch {
            SentryClient.shared.record(level: .error, errorOrMessage: .right("LogCollectionError 😵🗂️. Failed deleteOlderThanSevenDaysFiles: \(error)"))
        }
    }

    /// Delete old files in order of creation so that the older ones are deleted first until the total size of the directory is less than maximumArchiveSize
    func pruneFilesToMaintainDirectorySizeLimit() {
        do {
            let allArchivedFiles = try getAllArchivedFiles().sorted(by: { $0.lastModificationDate < $1.lastModificationDate })
            var totalSize = try getTotalSizeOfDirectory()
            for file in allArchivedFiles {
                guard totalSize > maximumArchiveSize else {
                    return
                }
                totalSize -= file.fileSize ?? 0
                try fileManager.removeItem(at: file)
            }
        } catch {
            SentryClient.shared.record(level: .error, errorOrMessage: .right("LogCollectionError 😵🗂️. Failed pruneFilesToMaintainDirectorySizeLimit: \(error)"))
        }
    }

    private func getTotalSizeOfDirectory() throws -> Int {
        let allArchivedFiles = try getAllArchivedFiles()
        return allArchivedFiles.compactMap({ $0.fileSize }).reduce(0, +)
    }

    private func getAllArchivedFiles() throws -> [URL] {
        try fileManager.contentsOfDirectory(at: archiveDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
    }
}
