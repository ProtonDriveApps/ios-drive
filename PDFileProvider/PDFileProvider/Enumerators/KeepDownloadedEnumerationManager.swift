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

import FileProvider
import PDCore
import CoreData
import ProtonCoreObservability

public class KeepDownloadedEnumerationManager {
    private static let keepDownloadedQueue = LocalItemsAwaitingEnumeration()
    private static let removeDownloadedQueue = LocalItemsAwaitingEnumeration()

    private let fileSystemSlot: FileSystemSlot
    private let fileProviderManager: NSFileProviderManager

    public init(fileSystemSlot: FileSystemSlot,
                fileProviderManager: NSFileProviderManager) {
        self.fileSystemSlot = fileSystemSlot
        self.fileProviderManager = fileProviderManager
    }

    public func setKeepDownloadedState(to keepDownloaded: Bool, for itemIdentifiers: [NSFileProviderItemIdentifier], moc: NSManagedObjectContext) {
        
        setKeepDownloadedStateSync(to: keepDownloaded, for: itemIdentifiers, moc: moc)
        let queue = keepDownloaded ? Self.keepDownloadedQueue : Self.removeDownloadedQueue
        queue.push(itemIdentifiers)
        
        Task {
            do {
                Log.event(.signalEnumerator(.started(.init(containerType: .workingSet, reason: .keepDownloadedStateChanged))))
                try await fileProviderManager.signalEnumerator(for: .workingSet)
                Log.event(.signalEnumerator(.succeeded(.init(containerType: .workingSet, reason: .keepDownloadedStateChanged))))
            } catch {
                Log.event(.signalEnumerator(.failed(.init(id: NSFileProviderItemIdentifier.workingSet.logIdentifier,
                                                          error: error))))
                Log.error("Failed to signal enumerator", error: error, domain: .offlineAvailable)
            }
        }
    }

    private func setKeepDownloadedStateSync(to keepDownloaded: Bool, for itemIdentifiers: [NSFileProviderItemIdentifier], moc: NSManagedObjectContext) {
        let nodeIdentifiers = itemIdentifiers.compactMap { itemIdentifier in
            return NodeIdentifier(itemIdentifier)
        }

        let nodes = fileSystemSlot.getNodes(nodeIdentifiers, moc: moc)

        do {
            try moc.performAndWait { [self] in
                rawSetKeepDownloadedState(to: keepDownloaded, for: nodes)

                try moc.saveOrRollback()
            }
        } catch {
            Log.error("Failed to update keep downloaded states", error: error, domain: .offlineAvailable)
        }

        sendActionMetric(keepDownloaded: keepDownloaded, for: nodes)
    }

    private func sendActionMetric(keepDownloaded: Bool, for nodes: [Node]) {
        nodes.forEach { node in
            let type: DriveKeepDownloadedFileType = (node is File) ? .file : .folder
            ObservabilityEnv.report(
                ObservabilityEvent.keepDownloadedActionEvent(action: keepDownloaded ? .keep_downloaded : .remove_download,
                                                       type: type)
            )
        }
    }

    // Must be called inside NSManagedObjectContext
    private func rawSetKeepDownloadedState(to state: Bool, for nodes: [Node]) {
        nodes.forEach {
            $0.isMarkedOfflineAvailable = state
            $0.isInheritingOfflineAvailable = false
        }
    }

    private func inheritKeepDownloadedState(for nodes: [Node], moc: NSManagedObjectContext) {
        do {
            try moc.performAndWait { [self] in
                let nodes = nodes.map { $0.in(moc: moc) }
                rawInheritKeepDownloadedState(for: nodes)
                try moc.saveOrRollback()
            }
        } catch {
            Log.error("Failed to update inheriting keep downloaded states", error: error, domain: .offlineAvailable)
        }
    }

    // Must be called inside NSManagedObjectContext
    private func rawInheritKeepDownloadedState(for nodes: [Node]) {
        nodes.forEach {
            if let parent = $0.parentFolder {
                $0.isMarkedOfflineAvailable = false
                $0.isInheritingOfflineAvailable = parent.isAvailableOffline
            }
        }
    }

    public func updateStateBasedOnParent(for nodes: [Node], moc: NSManagedObjectContext) {
        var keepDownloadedNodes: [Node] = []
        var inheritKeepDownloadedNodes: [Node] = []

        do {
            try moc.performAndWait { [self] in
                let nodes = nodes.map { $0.in(moc: moc) }
                nodes.forEach { node in
                    if shouldUpdateKeepDownloadedStateBasedOnParent(for: node) {
                        keepDownloadedNodes.append(node)
                    } else if shouldUpdateInheritingKeepDownloadedStateBasedOnParent(for: node) {
                        inheritKeepDownloadedNodes.append(node)
                    }
                }

                rawSetKeepDownloadedState(to: true, for: keepDownloadedNodes)
                rawInheritKeepDownloadedState(for: inheritKeepDownloadedNodes)

                try moc.saveOrRollback()
            }
        } catch {
            Log.error("Failed to update keep downloaded states", error: error, domain: .offlineAvailable)
        }

        let updatedNodes = (keepDownloadedNodes + inheritKeepDownloadedNodes)
        let itemIdentifiers = updatedNodes.map { NSFileProviderItemIdentifier($0.identifier) }
        Self.keepDownloadedQueue.push(itemIdentifiers)

        Task {
            do {
                Log.event(.signalEnumerator(.started(.init(containerType: .workingSet, reason: .keepDownloadedStateUpdatedBasedOnParent))))
                try await fileProviderManager.signalEnumerator(for: .workingSet)
                Log.event(.signalEnumerator(.succeeded(.init(containerType: .workingSet, reason: .keepDownloadedStateUpdatedBasedOnParent))))
            } catch {
                Log.event(.signalEnumerator(.failed(.init(id: NSFileProviderItemIdentifier.workingSet.logIdentifier,
                                                          error: error))))
                Log.error("Failed to signal enumerator", error: error, domain: .offlineAvailable)
            }
        }
    }

    // Must be called inside NSManagedObjectContext
    private func shouldUpdateKeepDownloadedStateBasedOnParent(for node: Node) -> Bool {
        guard let parent = node.parentFolder else { return false }

        // Nodes has moved from a keep downloaded parent to a non-keep downloaded parent,
        // where it should keep being kept downloaded
        return node.isInheritingOfflineAvailable && !parent.isAvailableOffline
    }

    // Must be called inside NSManagedObjectContext
    private func shouldUpdateInheritingKeepDownloadedStateBasedOnParent(for node: Node) -> Bool {
        guard let parent = node.parentFolder else { return false }

        // Node has moved into keep downloaded folder,
        // where it should now be kept downloaded
        return !node.isMarkedOfflineAvailable && parent.isAvailableOffline
    }

    public func processKeepDownloadedItems(
        _ observers: [NSFileProviderChangeObserver], moc: NSManagedObjectContext
    ) {
        let identifiers = Self.keepDownloadedQueue.popNextPage()
        guard !identifiers.isEmpty else { return }

        let enumeratedNodes = enumerateDownloadedItems(identifiers, observers: observers, moc: moc)
        
        keepChildrenDownloaded(for: enumeratedNodes, moc: moc)

        Task {

            do {
                Log.event(.signalEnumerator(.started(.init(containerType: .workingSet, reason: .keepDownloadedStateProcessItems))))
                try await fileProviderManager.signalEnumerator(for: .workingSet)
                Log.event(.signalEnumerator(.succeeded(.init(containerType: .workingSet, reason: .keepDownloadedStateProcessItems))))
            } catch {
                Log.event(.signalEnumerator(.failed(.init(id: NSFileProviderItemIdentifier.workingSet.logIdentifier,
                                                          error: error))))
                Log.error("Failed to signal enumerator", error: error, domain: .offlineAvailable)
            }
        }
    }

    public func processRemoveDownloadedItems(
        _ observers: [NSFileProviderChangeObserver], moc: NSManagedObjectContext
    ) {
        let identifiers = Self.removeDownloadedQueue.popNextPage()
        guard !identifiers.isEmpty else { return }
        Log.info("Processing remove-download batch: \(identifiers.count) item(s)", domain: .offlineAvailable)

        let enumeratedNodes = enumerateDownloadedItems(identifiers, observers: observers, moc: moc)
        
        keepChildrenDownloaded(for: enumeratedNodes, moc: moc)
        evict(enumeratedNodes, moc: moc)

        Task {
            do {
                Log.event(.signalEnumerator(.started(.init(containerType: .workingSet, reason: .removeDownloadedStateChanged))))
                try await fileProviderManager.signalEnumerator(for: .workingSet)
                Log.event(.signalEnumerator(.succeeded(.init(containerType: .workingSet, reason: .removeDownloadedStateChanged))))
            } catch {
                Log.event(.signalEnumerator(.failed(.init(id: NSFileProviderItemIdentifier.workingSet.logIdentifier,
                                                          error: error))))
                Log.error("Failed to signal enumerator", error: error, domain: .offlineAvailable)
            }
        }
    }

    private func evict(_ nodes: [Node], moc: NSManagedObjectContext) {
        let parentGroups = moc.performAndWait {
            return nodes.reduce(into: [NSFileProviderItemIdentifier: [NSFileProviderItemIdentifier]]()) {
                guard let parentFolder = $1.parentFolder else { return }

                let key = parentFolder.isRoot ? NSFileProviderItemIdentifier.rootContainer : NSFileProviderItemIdentifier(parentFolder.identifier)
                $0[key, default: []].append(NSFileProviderItemIdentifier($1.identifier))
            }
        }

        parentGroups.keys.forEach { parentIdentifier in
            // Continue with other operations asynchronously
            fileProviderManager.waitForChanges(below: parentIdentifier) { [self] error in
                if let error {
                    Log.warning(
                        "waitForChanges below \(parentIdentifier.rawValue) failed before eviction: \(error.localizedDescription)",
                        domain: .offlineAvailable
                    )
                }
                Task {
                    guard let evictionIdentifiers = parentGroups[parentIdentifier], !evictionIdentifiers.isEmpty else { return }

                    Log.info("Will evict \(evictionIdentifiers.count) item(s) below \(parentIdentifier.rawValue)", domain: .offlineAvailable)
                    await evict(evictionIdentifiers)
                }
            }
        }
    }

    private func evict(_ identifiers: [NSFileProviderItemIdentifier]) async {
        await identifiers.forEach { identifier in
            do {
                // Still attempt to evict even if waiting for changes fails
                try await fileProviderManager.evictItem(identifier: identifier)
                Log.info("Evicted item \(identifier.rawValue)", domain: .offlineAvailable)
            } catch {
                let nsError = error as NSError
                Log.error(
                    "Eviction failed for \(identifier.rawValue) [\(nsError.domain) \(nsError.code)]",
                    error: error,
                    domain: .offlineAvailable
                )
            }
        }
    }

    private func enumerateDownloadedItems(
        _ identifiers: [NSFileProviderItemIdentifier],
        observers: [NSFileProviderChangeObserver],
        moc: NSManagedObjectContext
    ) -> [Node] {
        let nodeIdentifiers = identifiers.compactMap { NodeIdentifier($0) }
        if nodeIdentifiers.count != identifiers.count {
            Log.warning("\(identifiers.count - nodeIdentifiers.count) identifier(s) dropped as malformed", domain: .offlineAvailable)
        }

        let nodes = fileSystemSlot.getNodes(nodeIdentifiers, moc: moc)
        if nodes.count != nodeIdentifiers.count {
            Log.warning("\(nodeIdentifiers.count - nodes.count) node(s) not found in storage", domain: .offlineAvailable)
        }

        let nodeItems = nodes.compactMap { try? NodeItem(node: $0) }
        if nodeItems.count != nodes.count {
            Log.warning("\(nodes.count - nodeItems.count) NodeItem(s) failed to build", domain: .offlineAvailable)
        }
        guard !nodeItems.isEmpty else { return [] }

        // Must be run on the same thread as `finishEnumeratingItems`
        observers.forEach { $0.didUpdate(nodeItems) }

        return nodes
    }

    private func keepChildrenDownloaded(for parents: [Node], moc: NSManagedObjectContext) {
        guard !parents.isEmpty else { return }

        let children = parents.flatMap { node in
            fileSystemSlot.getChildren(of: node.identifier, sorting: .default, moc: moc)
        }

        guard !children.isEmpty else { return }

        inheritKeepDownloadedState(for: children, moc: moc)

        let childItemIdentifiers = children.map { NSFileProviderItemIdentifier($0.identifier) }
        Self.keepDownloadedQueue.push(childItemIdentifiers)
    }
}
