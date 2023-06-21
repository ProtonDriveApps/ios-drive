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

protocol EnumeratorWithChanges: LogObject {
    var shareID: String { get }
    var eventsManager: EventsSystemManager { get }
    var fileSystemSlot: FileSystemSlot { get }
    var cloudSlot: CloudSlot { get }
}

extension EnumeratorWithChanges {
    // MARK: Changes Tracking
    
    private func latestAnchor() -> NSFileProviderSyncAnchor? {
        #if os(iOS)
        return latestAnchorIOS()
        #else
        return latestAnchorMacOS()
        #endif
    }

    private func latestAnchorIOS() -> NSFileProviderSyncAnchor? {
        guard let eventID = eventsManager.lastProcessedEvent()?.eventId ?? cloudSlot.lastScannedEventID,
              let referenceDate = cloudSlot.referenceDate else
        {
            return nil
        }

        return NSFileProviderSyncAnchor(anchor: .init(eventID: eventID, shareID: shareID, referenceDate: referenceDate))
    }

    private func latestAnchorMacOS() -> NSFileProviderSyncAnchor? {
        guard let event = eventsManager.lastReceivedEvent() else {
            return nil
        }

        let eventID = event.eventId
        let eventDate = Date(timeIntervalSince1970: event.eventEmittedAt)

        return NSFileProviderSyncAnchor(anchor: .init(eventID: eventID, shareID: shareID, referenceDate: eventDate))
    }
    
    func currentSyncAnchor(_ completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let anchor = latestAnchor()
        ConsoleLogger.shared?.log("⚓️ current sync anchor: " + String(describing: anchor), osLogType: Self.self)
        completionHandler(anchor)
    }
    
    func enumerateChanges(_ observer: NSFileProviderChangeObserver, _ syncAnchor: NSFileProviderSyncAnchor) {
        ConsoleLogger.shared?.log("🔄 enumerating changes", osLogType: Self.self)

        #if os(iOS)
        enumerateChangesIOS(observer, syncAnchor)
        #else
        enumerateChangesMacOS(observer, syncAnchor)
        #endif
    }

    private func enumerateChangesIOS(_ observer: NSFileProviderChangeObserver, _ syncAnchor: NSFileProviderSyncAnchor) {
        // no known events means no changes
        guard let newSyncAnchor = self.latestAnchor() else {
            observer.finishEnumeratingWithError(Errors.mapToFileProviderError(Errors.couldNotProduceSyncAnchor)!)
            return
        }

        enumerateChangesCommon(observer, syncAnchor, newSyncAnchor)
    }

    private func enumerateChangesMacOS(_ observer: NSFileProviderChangeObserver, _ syncAnchor: NSFileProviderSyncAnchor) {
        // on macOS we only process events here, latestAnchor might be nil on the first run
        eventsManager.forceProcessEvents()

        // no known events means no changes
        guard let newSyncAnchor = self.latestAnchor() else {
            observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
            return
        }

        enumerateChangesCommon(observer, syncAnchor, newSyncAnchor)
    }

    private func enumerateChangesCommon(_ observer: NSFileProviderChangeObserver, _ syncAnchor: NSFileProviderSyncAnchor, _ newSyncAnchor: NSFileProviderSyncAnchor) {
        // same anchor means no new events
        guard newSyncAnchor != syncAnchor else {
            ConsoleLogger.shared?.log("Sync anchor did not change" + String(describing: syncAnchor), osLogType: Self.self)
            observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
            return
        }

        // tracking changes across logins does not make sense because they are event-based
        guard newSyncAnchor[\.referenceDate] != syncAnchor[\.referenceDate] else {
            observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
            return
        }

        var itemsToDelete: [NSFileProviderItemIdentifier] = []
        var nodesToUpdate: [Node] = []

        do {
            let events = try eventsManager.eventsHistory(since: syncAnchor[\.eventID])
            ConsoleLogger.shared?.log("History: \(events.count) events", osLogType: Self.self)
            events.forEach { self.categorize(row: $0, into: &nodesToUpdate, or: &itemsToDelete) }
        } catch let error {
            ConsoleLogger.shared?.log(error, osLogType: Self.self)
        }

        if !itemsToDelete.isEmpty {
            ConsoleLogger.shared?.log("Delete: \(itemsToDelete.count) events", osLogType: Self.self)
            observer.didDeleteItems(withIdentifiers: itemsToDelete)
        }

        // successful completion
        let completion: () -> Void = {
            ConsoleLogger.shared?.log("Enumerated changes from sync anchor \(syncAnchor) till " + String(describing: newSyncAnchor), osLogType: Self.self)
            observer.finishEnumeratingChanges(upTo: newSyncAnchor, moreComing: false)
        }

        guard let moc = nodesToUpdate.first?.managedObjectContext else {
            completion()
            return
        }

        moc.perform {
            let itemsToUpdate = nodesToUpdate.map(NodeItem.init)
            ConsoleLogger.shared?.log("Update: \(itemsToUpdate.count)", osLogType: Self.self)
            observer.didUpdate(itemsToUpdate)
            completion()
        }
    }
    
    private func categorize(row: EventsSystemManager.EventsHistoryRow,
                            into nodesToUpdate: inout [Node],
                            or itemsToDelete: inout [NSFileProviderItemIdentifier])
    {
        switch row.event.genericType {
        case .delete:
            let nodeIdentifier = NodeIdentifier(row.event.inLaneNodeId, row.share)
            itemsToDelete.append(.init(nodeIdentifier))
            
        case .updateContent, .updateMetadata, .create:
            guard let node = self.fileSystemSlot.getNode(.init(row.event.inLaneNodeId, row.share)) else {
                return
            }
            
            if node.state == .deleted || node.state == .deleting {
                // trashed items need to be deleted from enumerator here - the fact that they do not appear in enumeration is not enough
                itemsToDelete.append(.init(node.identifier))
            } else {
                // others just updated
                nodesToUpdate.append(node)
            }
        default: break
        }
    }
}
