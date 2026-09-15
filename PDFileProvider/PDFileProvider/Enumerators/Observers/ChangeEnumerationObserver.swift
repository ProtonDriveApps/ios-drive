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

import FileProvider
import PDCore
import PDLocalization

public class ChangeEnumerationObserver: BaseEnumerationObserver, NSFileProviderChangeObserver {
    public static let enumerationSyncItemIdentifier = "enumerateChanges"
    private let enumerationSyncItemName = Localization.detecting_remote_changes

    /// Writes a terminal `.errored` state if finish is never issued (hung enumeration or torn-down
    /// extension), so the summary never stays `.inProgress`. Must exceed the slowest enumeration.
    private let watchdogTimeout: TimeInterval
    private let watchdogLock = NSLock()
    private var watchdog: Task<Void, Never>?

    public init(syncStorage: SyncStorageManager, watchdogTimeout: TimeInterval = 1800) {
        self.watchdogTimeout = watchdogTimeout
        super.init(syncStorage: syncStorage)
    }

    public func didStartEnumeratingChanges(name: String) {
        Log.trace("name: \(name)")

        let item = ReportableSyncItem(
            id: ChangeEnumerationObserver.enumerationSyncItemIdentifier,
            modificationTime: Date.now,
            filename: enumerationSyncItemName,
            location: nil,
            mimeType: nil,
            fileSize: nil,
            operation: .enumerateChanges,
            state: .inProgress,
            progress: 0)

        syncStorage.enqueueWrite(for: Self.enumerationSyncItemIdentifier) { [syncStorage] in
            await syncStorage.backgroundContextPool.withContext { context in
                syncStorage.upsert(item, in: context)
            }
        }

        armWatchdog()
    }

    public func didUpdate(_ updatedItems: [any NSFileProviderItemProtocol]) {
        Log.trace("\(updatedItems.count) items")
    }

    public func didDeleteItems(withIdentifiers deletedItemIdentifiers: [NSFileProviderItemIdentifier]) {
        Log.trace("\(deletedItemIdentifiers.count) items")
    }

    public func finishEnumeratingChanges(upTo anchor: NSFileProviderSyncAnchor, moreComing: Bool) {
        Log.trace("(more coming? \(moreComing))")
        if !moreComing {
            self.didFinishEnumeratingChanges(name: "", error: nil)
        }
    }

    public func finishEnumeratingWithError(_ error: any Error) {
        Log.trace("error: \(error.localizedDescription)")
        self.didFinishEnumeratingChanges(name: "", error: error)
    }

    private func didFinishEnumeratingChanges(name: String, error: Error?) {
        Log.trace("name: \(name), error: \(error?.localizedDescription ?? "n/a")")

        cancelWatchdog()
        
        let item = ReportableSyncItem(
            id: ChangeEnumerationObserver.enumerationSyncItemIdentifier,
            modificationTime: Date.now,
            filename: enumerationSyncItemName,
            location: nil,
            mimeType: nil,
            fileSize: nil,
            operation: .enumerateChanges,
            state: error == nil ? .finished : .errored,
            progress: error == nil ? 100 : 0,
            errorDescription: error?.localizedDescription)

        syncStorage.enqueueWrite(for: Self.enumerationSyncItemIdentifier) { [syncStorage] in
            await syncStorage.backgroundContextPool.withContext { context in
                syncStorage.upsert(item, in: context)
            }
        }
    }

    private func armWatchdog() {
        let timeout = watchdogTimeout
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.fireWatchdog()
        }
        watchdogLock.lock()
        let previous = watchdog
        watchdog = task
        watchdogLock.unlock()
        previous?.cancel()
    }

    private func cancelWatchdog() {
        watchdogLock.lock()
        let task = watchdog
        watchdog = nil
        watchdogLock.unlock()
        task?.cancel()
    }

    private func fireWatchdog() {
        Log.error("Change enumeration watchdog fired without finish callback; forcing terminal .errored state", domain: .enumerating)
        let item = ReportableSyncItem(
            id: Self.enumerationSyncItemIdentifier,
            modificationTime: Date.now,
            filename: enumerationSyncItemName,
            location: nil,
            mimeType: nil,
            fileSize: nil,
            operation: .enumerateChanges,
            state: .errored,
            progress: 0,
            errorDescription: "Enumeration timed out")

        syncStorage.enqueueWrite(for: Self.enumerationSyncItemIdentifier) { [syncStorage] in
            await syncStorage.backgroundContextPool.withContext { context in
                syncStorage.upsert(item, updateIf: { $0.inProgress }, in: context)
            }
        }
    }

    deinit {
        watchdog?.cancel()
        Log.trace()
    }
}
