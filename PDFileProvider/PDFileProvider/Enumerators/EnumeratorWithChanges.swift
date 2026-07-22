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
import CoreData

protocol EnumeratorWithChanges: AnyObject {
    var shareID: String { get }
    var eventsManager: EventsSystemManager { get }
    var fileSystemSlot: FileSystemSlot { get }
    var cloudSlot: CloudSlotProtocol { get }
    var enumerationObserver: EnumerationObserverProtocol? { get }
    var keepDownloadedManager: KeepDownloadedEnumerationManager { get }
    var shouldReenumerateItems: Bool { get set }
    var displayChangeEnumerationDetails: Bool { get }
}

/// "Change" enumerations are when an item is added/remove/changed on the server.
extension EnumeratorWithChanges {
    
    // MARK: - Anchors
    
    private func prospectiveAnchor() throws -> NSFileProviderSyncAnchor {
        // Anchor includes latest event that touched metadata DB and moment when we began tracking events (login, cache clearing):
        // 1. latest event that has been applied to metadata DB but not enumerated yet
        // 2. otherwise, anchor can not be created and so there are no changes to be enumerated
        guard let eventID = eventsManager.lastUnenumeratedEvent()?.eventId,
              let referenceDate = eventsManager.eventSystemReferenceDate
        else {
            Log.trace("guard")
            throw Errors.couldNotProduceSyncAnchor
        }

        Log.trace()
        let anchor = NSFileProviderSyncAnchor.UnderlyingAnchor(
            eventID: eventID,
            shareID: shareID,
            eventSystemRerefenceDate: referenceDate
        )
        
        return NSFileProviderSyncAnchor(anchor: anchor)
    }
    
    func currentSyncAnchor(_ completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        // Anchor includes latest event that touched metadata DB and moment when we began tracking events (login, cache clearing):
        // 1. latest event that has been applied to metadata DB and enumerated
        // 2. otherwise, anchor can not be created becase no event has been fully processed yet
        guard let eventID = eventsManager.lastEnumeratedEvent()?.eventId,
              let referenceDate = eventsManager.eventSystemReferenceDate
        else {
            Log.trace("guard")
            completionHandler(nil)
            return
        }

        Log.trace()
        let anchor = NSFileProviderSyncAnchor.UnderlyingAnchor(
            eventID: eventID,
            shareID: shareID,
            eventSystemRerefenceDate: referenceDate
        )
        
        Log.info("⚓️ current sync anchor: " + String(describing: anchor), domain: .enumerating)
        completionHandler(NSFileProviderSyncAnchor(anchor: anchor))
    }
    
    func enumerateChanges(_ container: FileOperationEvent.ContainerType, _ observers: [NSFileProviderChangeObserver], _ syncAnchor: NSFileProviderSyncAnchor) {
        
        Log.event(.enumerateChanges(.started(.init(
            containerType: container,
            syncAnchor: syncAnchor.rawValue.base64EncodedString()
        ))))

        enumerationObserver?.changes.didStartEnumeratingChanges(name: syncAnchor.rawValue.description)

        #if os(iOS)
        enumerateChangesIOS(container, observers, syncAnchor)
        #else
        Task {
            await enumerateChangesMacOS(container, observers, syncAnchor)
        }
        #endif
    }

    @available(macOS, unavailable)
    private func enumerateChangesIOS(_ container: FileOperationEvent.ContainerType, _ observers: [NSFileProviderChangeObserver], _ syncAnchor: NSFileProviderSyncAnchor) {
        Log.trace()
        let moc = fileSystemSlot.storage.backgroundContext
        enumerateChangesCommon(container, observers, syncAnchor, moc: moc)
    }

    @available(iOS, unavailable)
    private func enumerateChangesMacOS(_ container: FileOperationEvent.ContainerType, _ observers: [NSFileProviderChangeObserver], _ syncAnchor: NSFileProviderSyncAnchor) async {
        Log.trace()
        await eventsManager.forceProcessEvents()
        await fileSystemSlot.storage.backgroundContextPool.withContext { moc in
            enumerateChangesCommon(container, observers, syncAnchor, moc: moc)
        }
    }
    
    private func reEnumerationIsNeeded(_ syncAnchor: NSFileProviderSyncAnchor, _ newSyncAnchor: NSFileProviderSyncAnchor) -> Bool {
        // reference date is date of last login or cache clearing
        // reference date changed -> reEnumerationIsNeeded
        guard !syncAnchor.rawValue.isEmpty else {
            Log.trace("guard")
            return false
        }

        Log.trace()
        return newSyncAnchor[\.referenceDate] != syncAnchor[\.referenceDate]
    }

    private func enumerateChangesCommon(_ container: FileOperationEvent.ContainerType, _ observers: [NSFileProviderChangeObserver], _ syncAnchor: NSFileProviderSyncAnchor, moc: NSManagedObjectContext) {
        guard !shouldReenumerateItems else {
            Log.trace("guard")
            // forces the `enumerateItems`
            observers.forEach {
                if $0 is ChangeEnumerationObserver {
                    $0.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
                } else {
                    $0.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
                }
            }
            Log.event(.enumerateChanges(.failed(.init(
                containerType: container, errorMessage: "Forcing items reenumeration"
            ))))
            shouldReenumerateItems = false
            return
        }

        processLocallyModifiedItemsAwaitingEnumeration(observers, moc: moc)

        Log.trace()
        let newSyncAnchor: NSFileProviderSyncAnchor
        do {
            newSyncAnchor = try prospectiveAnchor()
        } catch {
            guard syncAnchor.rawValue.isEmpty || syncAnchor[\.referenceDate] == eventsManager.eventSystemReferenceDate else {
                observers.forEach { $0.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired)) }
                Log.event(.enumerateChanges(.failed(.init(
                    containerType: container, errorMessage: "Sync anchor reference date mismatch: \(error.localizedDescription)"
                ))))
                return
            }

            observers.forEach { $0.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false) }
            Log.event(.enumerateChanges(.failed(.init(
                containerType: container, error: error
            ))))
            return
        }

        // same anchor means no new events
        guard newSyncAnchor != syncAnchor else {
            Log.info("Sync anchor did not change" + String(describing: syncAnchor), domain: .enumerating)
            observers.forEach { $0.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false) }
            Log.event(.enumerateChanges(.succeeded(.init(containerType: container, updatedItemIDs: [], deletedItemIDs: [], newSyncAnchor: nil))))
            return
        }

        guard !reEnumerationIsNeeded(syncAnchor, newSyncAnchor) else {
            observers.forEach { $0.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired)) }
            Log.event(.enumerateChanges(.failed(.init(
                containerType: container, errorMessage: "Sync anchor needs reenumeration"
            ))))
            return
        }

        var itemsToDelete: [NSFileProviderItemIdentifier] = []
        var nodesToUpdate: [Node] = []
        var nodesToReport: [(Node, FileProviderOperation)] = []
        do {
            let events = try eventsManager.eventsHistory(since: syncAnchor[\.eventID])
            Log.info("History: \(events.count) events", domain: .enumerating)
            events.forEach {
                self.categorize(
                    row: $0,
                    into: &nodesToUpdate,
                    or: &itemsToDelete,
                    and: &nodesToReport,
                    using: moc
                )
            }
            eventsManager.setEnumerated(events.map { $0.objectID })
        } catch let error {
            Log.error("Error fetching events history", error: error, domain: .enumerating)
        }

        if !itemsToDelete.isEmpty {
            observers.forEach { $0.didDeleteItems(withIdentifiers: itemsToDelete) }
        }

        // successful completion
        let completion: () -> Void = {
            observers.forEach { $0.finishEnumeratingChanges(upTo: newSyncAnchor, moreComing: false) }
        }

        let itemsToUpdate = nodesToUpdate.compactMap {
            try? NodeItem(node: $0)
        }

        observers.forEach { $0.didUpdate(itemsToUpdate) }

        Log.event(.enumerateChanges(.succeeded(.init(
            containerType: container,
            updatedItemIDs: itemsToUpdate.map(\.itemIdentifier.rawValue),
            deletedItemIDs: itemsToDelete.map(\.rawValue),
            newSyncAnchor: newSyncAnchor.rawValue.base64EncodedString()
        ))))
        completion()

        // `reportEnumeratedChange` updates the state of this SyncItem to .enumerateChanges.
        // If items in this state are not being displayed, this update would cause the SyncItem to disappear,
        // so we don't do it in that scenario.
        if self.displayChangeEnumerationDetails {
            let itemsToReport = moc.performAndWait { [self] in
                nodesToReport.compactMap { (node, operation) in
                    self.reportableSyncItem(for: node, operation: operation)
                }
            }
            itemsToReport.forEach { item in
                self.report(for: item)
            }
        }

#if os(macOS)
        keepDownloadedManager.updateStateBasedOnParent(for: nodesToUpdate, moc: moc)
#endif
    }

    private func processLocallyModifiedItemsAwaitingEnumeration(_ observers: [NSFileProviderChangeObserver], moc: NSManagedObjectContext) {
        keepDownloadedManager.processKeepDownloadedItems(observers, moc: moc)
        keepDownloadedManager.processRemoveDownloadedItems(observers, moc: moc)
    }

    /// Note: call from within NSManagedObjectContext!
    private func reportableSyncItem(
        for node: Node, operation: FileProviderOperation
    ) -> ReportableSyncItem? {
#if os(macOS)
        // Note: even if we don't want to display these items in the tray app, we need them to trigger showing "Syncing" status.
        do {
            let name = try node.decryptName()
            return ReportableSyncItem(
                id: node.identifier.rawValue,
                modificationTime: Date(),
                filename: name,
                location: nil,
                mimeType: node.mimeType,
                fileSize: node.presentableNodeSize,
                operation: operation,
                state: .finished,
                progress: 100,
                errorDescription: nil
            )
        } catch {
            return ReportableSyncItem(
                id: node.identifier.rawValue,
                modificationTime: Date(),
                filename: "Name not available",
                location: nil,
                mimeType: node.mimeType,
                fileSize: node.presentableNodeSize,
                operation: .enumerateChanges,
                state: .errored,
                progress: 0,
                errorDescription: "Access to file attribute (e.g. file name) not available. Please retry or contact support."
            )
        }
#else
        return nil
#endif
    }
    
    private func report(for reportableSyncItem: ReportableSyncItem) {
#if os(macOS)
        guard let syncStorage = fileSystemSlot.syncStorage else { return }
        Task {
            await syncStorage.backgroundContextPool.withContext { context in
                syncStorage.upsert(
                    reportableSyncItem,
                    updateIf: { $0.notModifiedWithin(seconds: SyncItem.changeEnumerationUpdateThreshold) },
                    in: context
                )
            }
        }
#endif
    }

    private func categorize(row: EventsSystemManager.EventsHistoryRow,
                            into nodesToUpdate: inout [Node],
                            or itemsToDelete: inout [NSFileProviderItemIdentifier],
                            and nodesToReport: inout [(Node, FileProviderOperation)],
                            using moc: NSManagedObjectContext)
    {
        Log.trace()
        switch row.event.genericType {
        case .delete:
            let shareID = !row.share.isEmpty ? row.share : shareID
            let nodeIdentifier = NodeIdentifier(row.event.inLaneNodeId, shareID, "")
            itemsToDelete.append(.init(nodeIdentifier))

            // This is a permanent deletion from trash (on BE).
            // The node was deleted from our Metadata DB when we called `forceProcessEvents()`
            // on our `EventsSystemManager`.
            //   With no node, we don't have enough info (e.g. filename) to present this in our sync
            // view UI. If we wish to display this, we will need to hold onto this info
            // before deleting the node.
            //   For now, we accept that macOS will NOT display permanently deleted item events.

        case .updateContent, .updateMetadata, .create:
            let nodeIdentifier = NodeIdentifier(row.event.inLaneNodeId, row.share, "")
            guard let node = self.fileSystemSlot.getNode(nodeIdentifier, moc: moc) else {
                Log.info("Event's node not found in storage - event has not yet been processed", domain: .enumerating)
                return
            }

            // We do this so that we don't show remotely trashed items locally.
            // When trashing locally, we mark the item as .excludedFromSync,
            // which disassociates the item and all children, preserving a local
            // copy before automatically requesting remote deletion (which we handle by
            // trashing) from remote server.
            //   This is prefered due to the differences between macOS's more complex
            // trash capabilities and our BE model.
            if node.state == .deleted {
                itemsToDelete.append(.init(nodeIdentifier))
                nodesToReport.append((node, .remoteTrash))
            } else if row.event.genericType == .create {
                nodesToUpdate.append(node)
                nodesToReport.append((node, .remoteCreate))
            } else {
                nodesToUpdate.append(node)
                nodesToReport.append((node, .enumerateChanges))
            }
        }
    }
}

extension SyncItem {
    /// Minimum amount of time which needs to pass after a file operation, before an change enumeration of that item is not ignored.
    static let changeEnumerationUpdateThreshold: TimeInterval = 180

    func notModifiedWithin(seconds: TimeInterval) -> Bool {
        let threshold = Date.timeIntervalSinceReferenceDate - seconds

        Log.trace("\(modificationTime.timeIntervalSinceReferenceDate) < \(threshold) = \(modificationTime.timeIntervalSinceReferenceDate < threshold) (\(modificationTime.timeIntervalSinceReferenceDate - threshold))")

        return modificationTime.timeIntervalSinceReferenceDate < threshold
    }
}

extension FileOperationEvent.ContainerType {
    var identifier: String {
        switch self {
        case .rootContainer: return NSFileProviderItemIdentifier.rootContainer.rawValue
        case .trashContainer: return NSFileProviderItemIdentifier.trashContainer.rawValue
        case .workingSet: return NSFileProviderItemIdentifier.workingSet.rawValue
        case .folder(let id): return id
        }
    }
}
