// Copyright (c) 2023 Proton AG
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
import FileProvider
import PDLoadTesting

public enum SyncReportingControllerError: Error {
    case failedToResolveItem
    case failedToReportItem
}

public class SyncReportingController: SyncReporting, CommunicationServiceReporter {

    private let storage: SyncStorageManager

    private var updatesContinuation: AsyncStream<ReportableSyncItem>.Continuation?

    @SettingsStorage(UserDefaults.NotificationPropertyKeys.syncErrorDBUpdateKey.rawValue)
    private(set) var syncErrorDBUpdate: TimeInterval?

    public init(storage: SyncStorageManager, suite: SettingsStorageSuite, appTarget: AppTarget) {
        self.storage = storage
        _syncErrorDBUpdate.configure(with: suite)
    }

    // MARK: CommunicationServiceReporter

    public func post(update: ReportableSyncItem) throws {
        let moc = storage.mainContext
        try storage.upsert(update, in: moc)
        if update.fileProviderOperation == .create {        
            logItemUpload(update)
        }
    }

    public func logItemUpload(_ item: ReportableSyncItem) {
        guard LoadTesting.isEnabled else { return }
        guard !item.isFolder else { return }
        guard item.state != .undefined else { return }
        let timestamp = ISO8601DateFormatter().string(from: item.modificationTime)
        let status = item.state.logName
        let path = item.location ?? ""
        let formattedPath = path.replacingOccurrences(of: "\\", with: "/")
        let logEntry = LoadTestingLogEntry(
            timestamp: timestamp,
            status: status,
            path: formattedPath,
            fileSize: item.fileSize,
            operation: item.fileProviderOperation.name)

        if let jsonData = try? JSONEncoder().encode(logEntry),
           var jsonString = String(data: jsonData, encoding: .utf8) {
            jsonString = jsonString.replacingOccurrences(of: "\\/", with: "/")
            Log.info("\(jsonString)", domain: .loadTesting)
        }
    }

    // MARK: - SyncReporting

    public func update(item: ReportableSyncItem) {
        do {
            try post(update: item)
        } catch {
            Log.error("Error when updating item: \(error.localizedDescription)",
                      domain: .ipc)
        }
    }

    // MARK: FileProviderErrorReporting

    public func report(item: ReportableSyncItem) {
        do {
            let moc = storage.mainContext
            try post(update: item)
            self.syncErrorDBUpdate = Date().timeIntervalSince1970
            let count = storage.syncErrorsCount(in: moc)
            Log.debug("Total count of errors: \(count)", domain: .syncing)
        } catch {
            Log.error(error.localizedDescription, domain: .ipc)
        }
    }

    public func resolve(item: ReportableSyncItem) {
        do {
            try post(update: item)
            self.syncErrorDBUpdate = Date().timeIntervalSince1970
        } catch {
            Log.error("Fail to resolve item: \(error.localizedDescription)", domain: .syncing)
        }
    }

    public func updateTemporaryItem(id: String, with createdItem: ReportableSyncItem) throws {
        let moc = storage.mainContext
        try storage.updateTemporaryItem(id: id, with: createdItem, in: moc)
        logItemUpload(createdItem)
    }

    public func resolveTrash(id: String) {
        do {
            let moc = storage.mainContext
            try storage.updateTrashState(identifier: id, state: .finished, in: moc)
            self.syncErrorDBUpdate = Date().timeIntervalSince1970
        } catch {
            Log.error("Fail to update state for item in trash", domain: .syncing)
        }
    }

    public func cleanSyncItems(olderThan date: Date) throws {
        try storage.deleteSyncItems(olderThan: date, in: storage.mainContext)
    }

    public func cleanSyncingItems() {
        try? storage.cleanUpSyncingItems(in: storage.mainContext)
    }

}

private struct LoadTestingLogEntry: Encodable {
    let timestamp: String
    let status: String
    let path: String
    let fileSize: Int?
    let operation: String
}
