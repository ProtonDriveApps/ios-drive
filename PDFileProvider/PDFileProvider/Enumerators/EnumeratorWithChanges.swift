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

protocol EnumeratorWithChanges: AnyObject {
    var shareID: String { get }
    var eventsManager: EventsSystemManager { get }
    var fileSystemSlot: FileSystemSlot { get }
    var cloudSlot: CloudSlotProtocol { get }
    var changeObserver: FileProviderChangeObserver? { get }
    var shouldReenumerateItems: Bool { get set }
}

extension EnumeratorWithChanges {
    
    // MARK: - Anchors
    
    private func prospectiveAnchor() throws -> NSFileProviderSyncAnchor {
        // Anchor includes latest event that touched metadata DB and moment when we began tracking events (login, cache clearing):
        // 1. latest event that has been applied to metadata DB but not enumerated yet
        // 2. otherwise, anchor can not be created and so there are no changes to be enumerated
        guard let eventID = eventsManager.lastUnenumeratedEvent()?.eventId,
              let referenceDate = eventsManager.eventSystemReferenceDate
        else {
            throw Errors.couldNotProduceSyncAnchor
        }

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
            completionHandler(nil)
            return
        }

        let anchor = NSFileProviderSyncAnchor.UnderlyingAnchor(
            eventID: eventID,
            shareID: shareID,
            eventSystemRerefenceDate: referenceDate
        )
        
        Log.info("⚓️ current sync anchor: " + String(describing: anchor), domain: .fileProvider)
        completionHandler(NSFileProviderSyncAnchor(anchor: anchor))
    }
    
    func enumerateChanges(_ observers: [NSFileProviderChangeObserver], _ syncAnchor: NSFileProviderSyncAnchor) {
        Log.info("🔄 enumerating changes", domain: .fileProvider)
        changeObserver?.incrementSyncCounter(enumeratingChange: true)

        #if os(iOS)
        enumerateChangesIOS(observers, syncAnchor)
        #else
        enumerateChangesMacOS(observers, syncAnchor)
        #endif
    }

    @available(macOS, unavailable)
    private func enumerateChangesIOS(_ observers: [NSFileProviderChangeObserver], _ syncAnchor: NSFileProviderSyncAnchor) {
        enumerateChangesCommon(observers, syncAnchor)
    }

    @available(iOS, unavailable)
    private func enumerateChangesMacOS(_ observers: [NSFileProviderChangeObserver], _ syncAnchor: NSFileProviderSyncAnchor) {
        eventsManager.forceProcessEvents()
        enumerateChangesCommon(observers, syncAnchor)
    }
    
    private func reEnumerationIsNeeded(_ syncAnchor: NSFileProviderSyncAnchor, _ newSyncAnchor: NSFileProviderSyncAnchor) -> Bool {
        // reference date is date of last login or cache clearing
        // reference date changed -> reEnumerationIsNeeded
        guard !syncAnchor.rawValue.isEmpty else {
            return false
        }

        return newSyncAnchor[\.referenceDate] != syncAnchor[\.referenceDate]
    }

    private func enumerateChangesCommon(_ observers: [NSFileProviderChangeObserver], _ syncAnchor: NSFileProviderSyncAnchor) {
        guard !shouldReenumerateItems else {
            // forces the `enumerateItems`
            observers.forEach { $0.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired)) }
            Log.info("Forcing items reenumeration", domain: .forceRefresh)
            shouldReenumerateItems = false
            return
        }
        let newSyncAnchor: NSFileProviderSyncAnchor
        do {
            newSyncAnchor = try prospectiveAnchor()
        } catch {
            guard syncAnchor.rawValue.isEmpty || syncAnchor[\.referenceDate] == eventsManager.eventSystemReferenceDate else {
                observers.forEach { $0.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired)) }
                return
            }

            observers.forEach { $0.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false) }
            return
        }

        // same anchor means no new events
        guard newSyncAnchor != syncAnchor else {
            Log.info("Sync anchor did not change" + String(describing: syncAnchor), domain: .fileProvider)
            observers.forEach { $0.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false) }
            return
        }

        guard !reEnumerationIsNeeded(syncAnchor, newSyncAnchor) else {
            observers.forEach { $0.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired)) }
            return
        }

        var itemsToDelete: [NSFileProviderItemIdentifier] = []
        var nodesToUpdate: [Node] = []

        do {
            let events = try eventsManager.eventsHistory(since: syncAnchor[\.eventID])
            Log.info("History: \(events.count) events", domain: .events)
            events.forEach { self.categorize(row: $0, into: &nodesToUpdate, or: &itemsToDelete) }
            eventsManager.setEnumerated(events.map { $0.objectID })
        } catch let error {
            Log.error("Error fetching events history: \(error.localizedDescription) events", domain: .events)
        }

        if !itemsToDelete.isEmpty {
            Log.info("Delete: \(itemsToDelete.count) events", domain: .events)
            observers.forEach { $0.didDeleteItems(withIdentifiers: itemsToDelete) }
        }

        // successful completion
        let completion: () -> Void = {
            Log.info("Enumerated changes from sync anchor \(syncAnchor) till" + String(describing: newSyncAnchor), domain: .events)
            observers.forEach { $0.finishEnumeratingChanges(upTo: newSyncAnchor, moreComing: false) }
        }

        guard let moc = nodesToUpdate.first?.managedObjectContext else {
            completion()
            return
        }

        moc.perform { [weak self] in
            let itemsToUpdate = nodesToUpdate.compactMap {
                do {
                    return try NodeItem(node: $0)
                } catch {
                    #if os(macOS)
                    guard let self else { return nil }
                    let reportableSyncItem = ReportableSyncItem(
                        id: $0.identifier.rawValue,
                        modificationTime: Date(),
                        filename: "Error: Not available",
                        location: nil,
                        mimeType: $0.mimeType,
                        fileSize: $0.size,
                        operation: .enumerateChanges,
                        state: .errored,
                        description: "Access to file attribute (e.g., file name) not available. Please retry or contact support."
                    )
                    if let syncStorage = self.fileSystemSlot.syncStorage {
                        let syncReportingController = SyncReportingController(storage: syncStorage, suite: .group(named: Constants.appGroup), appTarget: .main)
                        syncReportingController.report(item: reportableSyncItem)
                    }
                    #endif
                    return nil
                }
            }
            Log.info("Update: \(itemsToUpdate.count)", domain: .events)
            observers.forEach { $0.didUpdate(itemsToUpdate) }
            completion()
        }
    }
    
    private func categorize(row: EventsSystemManager.EventsHistoryRow,
                            into nodesToUpdate: inout [Node],
                            or itemsToDelete: inout [NSFileProviderItemIdentifier])
    {
        switch row.event.genericType {
        case .delete:
            let shareID = !row.share.isEmpty ? row.share : shareID
            let nodeIdentifier = NodeIdentifier(row.event.inLaneNodeId, shareID, "")
            itemsToDelete.append(.init(nodeIdentifier))
            
        case .updateContent, .updateMetadata, .create:
            let nodeIdentifier = NodeIdentifier(row.event.inLaneNodeId, row.share, "")
            guard let node = self.fileSystemSlot.getNode(nodeIdentifier) else {
                Log.info("Event's node not found in storage - event has not yet been processed", domain: .events)
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
            } else {
                nodesToUpdate.append(node)
            }
        }
    }
}
