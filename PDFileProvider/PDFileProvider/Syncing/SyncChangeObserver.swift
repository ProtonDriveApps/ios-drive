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
import Foundation
import PDClient
import PDCore
import ProtonCoreUtilities

public enum SyncType {
    case push
    case pull
}

public protocol SyncOperationCounter {
    func incrementSyncCounter(enumeratingChange: Bool)
    func decrementSyncCounter(type: SyncType, error: Error?)
}

extension SyncOperationCounter {
    func incrementSyncCounter(enumeratingChange: Bool = false) {
        return incrementSyncCounter(enumeratingChange: enumeratingChange)
    }
}

public typealias FileProviderChangeObserver = SyncOperationCounter & NSFileProviderChangeObserver & NSFileProviderEnumerationObserver

public class SyncChangeObserver: NSObject, FileProviderChangeObserver {
    
    private let instanceIdentifier = UUID()

    private var syncOperationCount = Atomic(0)
    
    @FastStorage("awaitingNextEvent-Sync") private var awaitingNextEvent: Bool?
    private var enumeratingChange = false

    private var syncStatusUpdater = SyncStatusUpdater()

    private var syncError: Error?

    override public init() {
        Log.info("SyncFileObserver init: \(instanceIdentifier.uuidString)", domain: .syncing)
    }
    
    deinit {
        Log.info("SyncFileObserver deinit: \(instanceIdentifier.uuidString)", domain: .syncing)
    }

    // MARK: - NSFileProviderChangeObserver

    public func didUpdate(_ updatedItems: [NSFileProviderItemProtocol]) {
        Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): didUpdate \(updatedItems.count) items",
                 domain: .syncing)
    }

    public func didDeleteItems(withIdentifiers deletedItemIdentifiers: [NSFileProviderItemIdentifier]) {
        Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): didDelete \(deletedItemIdentifiers.count) items",
                 domain: .syncing)
    }

    public func finishEnumeratingChanges(upTo anchor: NSFileProviderSyncAnchor, moreComing: Bool) {
        Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): finishEnumeratingChanges anchor, more coming? \(moreComing)",
                 domain: .syncing)
        if !moreComing {
            self.decrementSyncCounter(type: .pull, error: nil)
        }
    }

    // MARK: - NSFileProviderEnumerationObserver

    public func didEnumerate(_ updatedItems: [NSFileProviderItemProtocol]) {
        Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): updatedItems: \(updatedItems.count) ", domain: .syncing)
    }

    public func finishEnumerating(upTo nextPage: NSFileProviderPage?) {
        Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): finishEnumerating up to nextPage: \(String(describing: nextPage?.int))", domain: .syncing)
        self.decrementSyncCounter(type: .pull, error: nil)
    }

    public func finishEnumeratingWithError(_ error: Error) {
        Log.error("SyncChangeObserver \(instanceIdentifier.uuidString): finishEnumeratingWithError: \(error.localizedDescription)", domain: .syncing)
        self.decrementSyncCounter(type: .pull, error: error)
    }

    // MARK: - SyncOperationCounter

    public func incrementSyncCounter(enumeratingChange: Bool = false) {
        if enumeratingChange && awaitingNextEvent == true {
            Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): Syncing operations not incremented", domain: .syncing)
            self.enumeratingChange = true
            return
        }
        syncOperationCount.mutate { syncCounterValue in
            syncCounterValue += 1
            Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): Syncing operations count incremented to \(syncCounterValue)", domain: .syncing)
            didUpdateSyncOperationCount(syncCounterValue)
        }
        
    }

    public func decrementSyncCounter(type: SyncType, error: Error?) {
        self.syncError = error
        if type == .pull && enumeratingChange && awaitingNextEvent == true {
            Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): Syncing operations not decremented", domain: .syncing)
            enumeratingChange = false
            awaitingNextEvent = false
            return
        }

        if type == .push {
            Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): Syncing operations awaiting next event", domain: .syncing)
            awaitingNextEvent = true
        }
        
        syncOperationCount.mutate { syncCounterValue in
            if syncCounterValue > 0 {
                syncCounterValue -= 1
                Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): Syncing operations count decremented to \(syncCounterValue)", domain: .syncing)
                didUpdateSyncOperationCount(syncCounterValue)
            } else {
                let errorMessage = "SyncChangeObserver \(instanceIdentifier.uuidString): Syncing operations count was not decremented because it would drop below zero"
                assertionFailure(errorMessage)
                Log.error(errorMessage, domain: .syncing)
            }
        }
    }
    
    private func didUpdateSyncOperationCount(_ newValue: Int) {
        if newValue > 0 {
            syncStatusChanged(to: true)
            Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): Sync status changed to true, value: \(newValue)", domain: .syncing)
        } else if newValue == 0 {
            syncStatusChanged(to: false)
            Log.info("SyncChangeObserver \(instanceIdentifier.uuidString): Sync status changed to false, value: \(newValue)", domain: .syncing)
        } else {
            let errorMessage = "SyncChangeObserver \(instanceIdentifier.uuidString): Syncing operations count below zero, error"
            assertionFailure(errorMessage)
            Log.error(errorMessage, domain: .syncing)
        }
    }

    private func syncStatusChanged(to syncing: Bool) {
        let error = syncError
        let updater = syncStatusUpdater
        Task {
            if error == nil && syncing == false {
                let now = Date()
                await updater.updateTime(with: now.timeIntervalSince1970)
            }
            await updater.updateSyncing(with: syncing)
        }
    }
}
