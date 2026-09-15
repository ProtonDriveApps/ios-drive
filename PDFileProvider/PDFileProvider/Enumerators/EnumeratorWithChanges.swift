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
    var eventsManager: EventsSystemManager { get }
    var fileSystemSlot: FileSystemSlot { get }
    var cloudSlot: CloudSlotProtocol { get }
    var enumerationObserver: EnumerationObserverProtocol? { get }
    var keepDownloadedManager: KeepDownloadedEnumerationManager { get }
    var resyncEnumerationService: ResyncEnumerationService? { get }
    var displayChangeEnumerationDetails: Bool { get }
    /// Holds the in-flight post-resync change-enumeration Task so invalidate() can cancel it.
    var resyncEnumerationTask: Task<Void, Never>? { get set }
}

/// Outcome of trying to build a sync anchor for the event-loop change enumeration. Modeled as a result
/// rather than a thrown error so the common idle cases are not reported as failures.
enum ProspectiveAnchorResult {
    case anchor(NSFileProviderSyncAnchor)
    /// Event system initialized but no unenumerated events — the common idle steady state.
    case noUnenumeratedEvents
    /// No reference date yet (event system not started / just after a cache-clear) — transiently not ready.
    case notReady

    static func make(unenumeratedEventID: String?, referenceDate: Date?, shareID: String) -> ProspectiveAnchorResult {
        guard let referenceDate else { return .notReady }
        guard let unenumeratedEventID else { return .noUnenumeratedEvents }
        return .anchor(NSFileProviderSyncAnchor(anchor: .init(
            eventID: unenumeratedEventID, shareID: shareID, eventSystemRerefenceDate: referenceDate
        )))
    }
}

/// "Change" enumerations are when an item is added/remove/changed on the server.
extension EnumeratorWithChanges {

    // MARK: - Anchors

    private func prospectiveAnchor(shareID: String) -> ProspectiveAnchorResult {
        // The anchor pairs the latest event applied to the metadata DB but not yet enumerated with the
        // reference date (login / cache-clear). No unenumerated event ⇒ nothing to report (idle); no
        // reference date ⇒ the event system is not ready. Neither is an error.
        ProspectiveAnchorResult.make(
            unenumeratedEventID: eventsManager.lastUnenumeratedEvent()?.eventId,
            referenceDate: eventsManager.eventSystemReferenceDate,
            shareID: shareID
        )
    }

    func currentSyncAnchor(
        shareID: String, _ completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void
    ) {
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

    func enumerateChanges(
        _ shareID: String,
        _ container: FileOperationEvent.ContainerType,
        _ observers: [NSFileProviderChangeObserver],
        _ syncAnchor: NSFileProviderSyncAnchor,
        _ type: String
    ) {

        Log.event(.enumerateChanges(.started(.init(
            containerType: container,
            syncAnchor: syncAnchor.rawValue.base64EncodedString()
        ))))

        enumerationObserver?.changes.didStartEnumeratingChanges(name: syncAnchor.rawValue.description)

        #if os(iOS)
        enumerateChangesIOS(shareID, container, observers, syncAnchor, type)
        #else
        Task {
            await enumerateChangesMacOS(shareID, container, observers, syncAnchor, type)
        }
        #endif
    }

    @available(macOS, unavailable)
    private func enumerateChangesIOS(
        _ shareID: String,
        _ container: FileOperationEvent.ContainerType,
        _ observers: [NSFileProviderChangeObserver],
        _ syncAnchor: NSFileProviderSyncAnchor,
        _ type: String
    ) {
        Log.trace()
        let moc = fileSystemSlot.storage.backgroundContext
        enumerateChangesCommon(shareID, container, observers, syncAnchor, type, moc)
    }

    @available(iOS, unavailable)
    private func enumerateChangesMacOS(
        _ shareID: String,
        _ container: FileOperationEvent.ContainerType,
        _ observers: [NSFileProviderChangeObserver],
        _ syncAnchor: NSFileProviderSyncAnchor,
        _ type: String
    ) async {
        Log.trace()
        if resyncEnumerationService == nil || resyncEnumerationService?.changesEnumerationMode == .eventLoop {
            await eventsManager.forceProcessEvents()
        }
        await fileSystemSlot.storage.backgroundContextPool.withContext { moc in
            enumerateChangesCommon(shareID, container, observers, syncAnchor, type, moc)
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

    private func enumerateChangesCommon(
        _ shareID: String,
        _ container: FileOperationEvent.ContainerType,
        _ observers: [NSFileProviderChangeObserver],
        _ syncAnchor: NSFileProviderSyncAnchor,
        _ type: String,
        _ moc: NSManagedObjectContext
    ) {

        guard let resyncEnumerationService else {
            enumerateChangesUsingEventLoop(shareID, container, observers, syncAnchor, moc)
            return
        }
        switch resyncEnumerationService.changesEnumerationMode {
        case .eventLoop:
            enumerateChangesUsingEventLoop(shareID, container, observers, syncAnchor, moc)
        case .fullResync, .userInitiatedRefresh:
            resyncEnumerationTask = Task {
                do {
                    try await resyncEnumerationService.enumerateChangesAfterResync(
                        fileSystemSlot: fileSystemSlot,
                        shareID: shareID,
                        observers: observers,
                        // macOS re-invokes with the anchor we returned; its cursor (nil for the first call,
                        // e.g. an event-origin anchor) drives which page to deliver. Mode stays .fullResync
                        // until the last page, so each re-invocation routes back here.
                        startingAtPage: syncAnchor.resyncPageOffset ?? 0,
                        prospectiveAnchor: { shareID in
                            // The reference is established at the start of the resync, before the snapshot.
                            // A nil here is an invariant violation: crash in development, degrade to a full
                            // re-enumeration in production (the catch below routes a throw to forceItemsEnumeration).
                            guard let eventID = self.eventsManager.eventSystemReferenceID,
                                  let referenceDate = self.eventsManager.eventSystemReferenceDate else {
                                Log.error("Event system reference missing at post-resync enumeration", domain: .enumerating)
                                assertionFailure("Event system reference must be set before post-resync enumeration")
                                throw Errors.couldNotProduceSyncAnchor
                            }
                            let anchor = NSFileProviderSyncAnchor.UnderlyingAnchor(
                                eventID: eventID,
                                shareID: shareID,
                                eventSystemRerefenceDate: referenceDate
                            )
                            return NSFileProviderSyncAnchor(anchor: anchor)
                        }
                    )
                } catch is CancellationError {
                    // Enumerator was invalidated (domain disconnect / sign-out / store replacement). The
                    // enumerateChangesAfterResync defer already reset mode/flag; do not force re-enumeration.
                    Log.trace("Post-resync change enumeration cancelled", domain: .enumerating)
                } catch {
                    Log.event(.enumerateChanges(.failed(.init(
                        containerType: container, errorMessage: "Forcing items reenumeration"
                    ))))
                    // as a recovery from the error, use the slower individual items refresh
                    resyncEnumerationService.forceItemsEnumeration(observers: observers, syncAnchor: syncAnchor)
                }
            }
        case .recoveryResync:
            Log.event(.enumerateChanges(.failed(.init(
                containerType: container, errorMessage: "Forcing items reenumeration"
            ))))
            resyncEnumerationService.forceItemsEnumeration(observers: observers, syncAnchor: syncAnchor)
        }
    }

    private func enumerateChangesUsingEventLoop(
        _ shareID: String,
        _ container: FileOperationEvent.ContainerType,
        _ observers: [NSFileProviderChangeObserver],
        _ syncAnchor: NSFileProviderSyncAnchor,
        _ moc: NSManagedObjectContext
    ) {
        processLocallyModifiedItemsAwaitingEnumeration(observers, moc)

        Log.trace()
        let newSyncAnchor: NSFileProviderSyncAnchor
        switch prospectiveAnchor(shareID: shareID) {
        case .anchor(let anchor):
            newSyncAnchor = anchor
        case .noUnenumeratedEvents, .notReady:
            // No changes to report right now (idle, or the event system isn't ready). Preserve the prior
            // decision: if the caller's anchor is still current, finish cleanly with no changes; if its
            // reference date is stale (post login / cache-clear), expire it to force a re-enumeration.
            // Both are expected — log accordingly so idle polls don't flood telemetry with errors.
            if syncAnchor.rawValue.isEmpty || syncAnchor[\.referenceDate] == eventsManager.eventSystemReferenceDate {
                observers.forEach { $0.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false) }
                Log.event(.enumerateChanges(.succeeded(.init(
                    containerType: container, updatedItemIDs: [], deletedItemIDs: [], newSyncAnchor: nil
                ))))
            } else {
                observers.forEach { $0.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired)) }
                Log.info("Change enumeration: sync anchor reference date changed — forcing re-enumeration",
                         domain: .enumerating)
            }
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
        var moreComing = false
        var finishAnchor = newSyncAnchor
        do {
            // Deliver one bounded batch of events (the history is sorted oldest-first) per round to stay
            // under NSFileProvider's per-page item limit. The event log is the cursor: enumerate the batch,
            // advance the anchor to its last event, and signal moreComing so macOS re-invokes for the next
            // batch. eventsHistory has no limit param, so a very large backlog costs O(N²/batch) across
            // rounds — acceptable for that rare case.
            let allEvents = try eventsManager.eventsHistory(since: syncAnchor[\.eventID])
            let batchSize = ChangesPaging.batchSize(for: observers)
            let batch = Array(allEvents.prefix(batchSize))
            moreComing = allEvents.count > batch.count
            Log.info("History: \(allEvents.count) events; delivering \(batch.count) this page; moreComing \(moreComing)", domain: .enumerating)
            batch.forEach {
                self.categorize(
                    row: $0,
                    into: &nodesToUpdate,
                    or: &itemsToDelete,
                    and: &nodesToReport,
                    shareID: shareID,
                    using: moc
                )
            }
            eventsManager.setEnumerated(batch.map { $0.objectID })
            // Resume right after this batch's last event next round; once caught up, keep the global anchor.
            if moreComing,
               let lastEventID = batch.last?.event.eventId,
               let referenceDate = newSyncAnchor[\.referenceDate] {
                finishAnchor = NSFileProviderSyncAnchor(anchor: .init(
                    eventID: lastEventID, shareID: shareID, eventSystemRerefenceDate: referenceDate
                ))
            }
        } catch let error {
            Log.error("Error fetching events history", error: error, domain: .enumerating)
        }

        if !itemsToDelete.isEmpty {
            observers.forEach { $0.didDeleteItems(withIdentifiers: itemsToDelete) }
        }

        let itemsToUpdate = nodesToUpdate.compactMap {
            try? NodeItem(node: $0)
        }

        observers.forEach { $0.didUpdate(itemsToUpdate) }

        Log.event(.enumerateChanges(.succeeded(.init(
            containerType: container,
            updatedItemIDs: itemsToUpdate.map(\.itemIdentifier.logIdentifier),
            deletedItemIDs: itemsToDelete.map(\.logIdentifier),
            newSyncAnchor: finishAnchor.rawValue.base64EncodedString()
        ))))
        observers.forEach { $0.finishEnumeratingChanges(upTo: finishAnchor, moreComing: moreComing) }

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

    private func processLocallyModifiedItemsAwaitingEnumeration(_ observers: [NSFileProviderChangeObserver], _ moc: NSManagedObjectContext) {
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
                            shareID: String,
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
