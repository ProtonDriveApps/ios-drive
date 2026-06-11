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
import CoreData

public struct TrashedNodesCleaner: Sendable {
    private let downloaders: [DownloaderProtocol]

    public init(downloaders: [DownloaderProtocol]) {
        self.downloaders = downloaders
    }

    // Run in NSManagedObjectContext
    public func cancelAndDeleteDownloadingTask(files: [CoreDataFile], in moc: NSManagedObjectContext) {
        let ids = files.map(\.identifierWithinManagedObjectContext)
        Log.debug("Cancel \(ids.count) downloads", domain: .downloader)
        downloaders.forEach { $0.cancel(operationsOf: ids) }

        files.forEach { deleteDownloadingBlock(from: $0, in: moc) }
    }

    private func deleteDownloadingBlock(from file: CoreDataFile, in moc: NSManagedObjectContext) {
        guard let revision = file.activeRevision else { return }
        let urls = revision.blocks.compactMap { $0.localUrl }
        revision.blocks.forEach(moc.delete)
        revision.blocks = Set([])
        Task.detached {
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
