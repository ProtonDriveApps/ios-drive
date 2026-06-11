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
import Foundation

/// Handle the trash action by resetting the offline available flag or canceling any ongoing download
public struct NodeTreeTrashHandler: NodeTreeTrashHandlerProtocol {
    private let cleaner: TrashedNodesCleaner
    private let performer: NodeTreeTrashPerformer

    public init(downloaders: [DownloaderProtocol]) {
        self.cleaner = TrashedNodesCleaner(downloaders: downloaders)
        self.performer = NodeTreeTrashPerformer()
    }

    // Run inside NSManagedObjectContext
    public func performAndSave(to nodes: [Node], in moc: NSManagedObjectContext) throws {
        let affectedFiles = performer.perform(to: nodes, in: moc)
        cleaner.cancelAndDeleteDownloadingTask(files: affectedFiles, in: moc)
        try moc.saveIfNeeded()
    }

    // Run inside NSManagedObjectContext
    public func perform(to nodes: [Node], in moc: NSManagedObjectContext) {
        let affectedFiles = performer.perform(to: nodes, in: moc)
        cleaner.cancelAndDeleteDownloadingTask(files: affectedFiles, in: moc)
    }
}
