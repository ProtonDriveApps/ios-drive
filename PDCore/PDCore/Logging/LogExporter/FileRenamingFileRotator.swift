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

public final class FileRenamingFileRotatorDecorator: FileLogRotator {
    private let fileManager = FileManager.default
    private let rotationDirectory = PDFileManager.logsRotationDirectory
    private let dateProvider: () -> Date
    private let rotator: FileLogRotator

    public init(
        rotator: FileLogRotator,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.rotator = rotator
        self.dateProvider = dateProvider
    }

    public func rotate(_ file: URL) {
        let newFile = renameFile(oldURL: file)
        rotator.rotate(newFile)
    }

    private func renameFile(oldURL: URL) -> URL {
        do {
            let newURL = getNewFileURL(from: oldURL)
            try fileManager.moveItem(at: oldURL, to: newURL)
            return newURL
        } catch {
            SentryClient.shared.record(level: .error, errorOrMessage: .right("LogCollectionError 😵🗂️. Failed to rename file: \(error)"))
            return oldURL
        }
    }

    private func getNewFileURL(from oldURL: URL) -> URL {
        let `extension` = oldURL.pathExtension
        let oldName = oldURL.deletingPathExtension().lastPathComponent
        let newName = getNewFileName(from: oldName)
        return rotationDirectory.appendingPathComponent(newName + "." + `extension`)
    }

    private func getNewFileName(from oldName: String) -> String {
        let dateFormatter = ISO8601DateFormatter.fileLogFormatter
        let newName = dateFormatter.string(from: dateProvider()).replacingOccurrences(of: ":", with: "-")
        return oldName + "_" + newName
    }
}
