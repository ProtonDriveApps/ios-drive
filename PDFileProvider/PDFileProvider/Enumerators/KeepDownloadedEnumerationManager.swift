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
import ProtonCoreObservability

public class KeepDownloadedEnumerationManager {
    private static let keepDownloadedQueue = LocalItemsAwaitingEnumeration()
    private static let removeDownloadedQueue = LocalItemsAwaitingEnumeration()

    private let storage: StorageManager
    private let fileSystemSlot: FileSystemSlot
    private let fileProviderManager: NSFileProviderManager

    public init(storage: StorageManager,
                fileSystemSlot: FileSystemSlot,
                fileProviderManager: NSFileProviderManager) {
        self.storage = storage
        self.fileSystemSlot = fileSystemSlot
        self.fileProviderManager = fileProviderManager
    }

    public func setKeepDownloadedState(to keepDownloaded: Bool, for itemIdentifiers: [NSFileProviderItemIdentifier]) {
        Task {
            await setKeepDownloadedState(to: keepDownloaded, for: itemIdentifiers)

            let queue = keepDownloaded ? Self.keepDownloadedQueue : Self.removeDownloadedQueue

            queue.push(itemIdentifiers)

            do {
                try await fileProviderManager.signalEnumerator(for: .workingSet)
            } catch {
                Log.error("Failed to signal enumerator", error: error, domain: .offlineAvailable)
            }
        }
    }

    private func setKeepDownloadedState(to keepDownloaded: Bool, for itemIdentifiers: [NSFileProviderItemIdentifier]) async {
        let moc = storage.backgroundContext
        let nodeIdentifiers = itemIdentifiers.compactMap { itemIdentifier in
            return NodeIdentifier(itemIdentifier)
        }

        let nodes = fileSystemSlot.getNodes(nodeIdentifiers, moc: moc)

        do {
            try await moc.perform { [self] in
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

    private func inheritKeepDownloadedState(for nodes: [Node]) {
        let moc = storage.backgroundContext

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

    public func updateStateBasedOnParent(for nodes: [Node]) {
        Task {
            await updateStateBasedOnParent(for: nodes)
        }
    }

    private func updateStateBasedOnParent(for nodes: [Node]) async {
        let moc = storage.backgroundContext

        var keepDownloadedNodes: [Node] = []
        var inheritKeepDownloadedNodes: [Node] = []

        do {
            try await moc.perform { [self] in
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

        do {
            try await fileProviderManager.signalEnumerator(for: .workingSet)
        } catch {
            Log.error("Failed to signal enumerator", error: error, domain: .offlineAvailable)
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

    public func processKeepDownloadedItems(_ observers: [NSFileProviderChangeObserver]) {
        let identifiers = Self.keepDownloadedQueue.popNextPage()
        guard !identifiers.isEmpty else { return }

        let enumeratedNodes = enumerateDownloadedItems(identifiers, observers: observers)

        Task {
            keepChildrenDownloaded(for: enumeratedNodes)

            do {
                try await fileProviderManager.signalEnumerator(for: .workingSet)
            } catch {
                Log.error("Failed to signal enumerator", error: error, domain: .offlineAvailable)
            }
        }
    }

    public func processRemoveDownloadedItems(_ observers: [NSFileProviderChangeObserver]) {
        let identifiers = Self.removeDownloadedQueue.popNextPage()
        guard !identifiers.isEmpty else { return }

        let enumeratedNodes = enumerateDownloadedItems(identifiers, observers: observers)

        Task {
            keepChildrenDownloaded(for: enumeratedNodes)
            evict(enumeratedNodes)

            do {
                try await fileProviderManager.signalEnumerator(for: .workingSet)
            } catch {
                Log.error("Failed to signal enumerator", error: error, domain: .offlineAvailable)
            }
        }
    }

    private func evict(_ nodes: [Node]) {
        let moc = storage.backgroundContext

        let parentGroups = moc.performAndWait {
            let nodes = nodes.map { $0.in(moc: moc) }

            return nodes.reduce(into: [NSFileProviderItemIdentifier: [Node]]()) {
                guard let parentFolder = $1.parentFolder else { return }

                let key = parentFolder.isRoot ? NSFileProviderItemIdentifier.rootContainer : NSFileProviderItemIdentifier(parentFolder.identifier)
                $0[key, default: []].append($1)
            }
        }

        parentGroups.keys.forEach { parentIdentifier in
            // Continue with other operations asynchronously
            fileProviderManager.waitForChanges(below: parentIdentifier) { [self] error in
                Task {
                    guard let finishedNodes = parentGroups[parentIdentifier], !finishedNodes.isEmpty else { return }

                    Log.trace("Will evict items")
                    await evictNodes(finishedNodes)
                }
            }
        }
    }

    private func evictNodes(_ nodes: [Node]) async {
        let itemIdentifiersToEvict = nodes.map { NSFileProviderItemIdentifier($0.identifier) }
        await itemIdentifiersToEvict.forEach {
            do {
                // Still attempt to evict even if waiting for changes fails
                try await fileProviderManager.evictItem(identifier: $0)
            } catch {
                Log.error("Eviction failed", error: error, domain: .offlineAvailable)
            }
        }
    }

    private func enumerateDownloadedItems(_ identifiers: [NSFileProviderItemIdentifier],
                                          observers: [NSFileProviderChangeObserver]) -> [Node] {
        let nodeIdentifiers = identifiers.compactMap { NodeIdentifier($0) }
        let nodes = fileSystemSlot.getNodes(nodeIdentifiers)

        let nodeItems = nodes.compactMap { try? NodeItem(node: $0) }
        guard !nodeItems.isEmpty else { return [] }

        // Must be run on the same thread as `finishEnumeratingItems`
        observers.forEach { $0.didUpdate(nodeItems) }

        return nodes
    }

    private func keepChildrenDownloaded(for parents: [Node]) {
        guard !parents.isEmpty else { return }

        let children = parents.flatMap { node in
            fileSystemSlot.getChildren(of: node.identifier, sorting: .default)
        }

        guard !children.isEmpty else { return }

        inheritKeepDownloadedState(for: children)

        let childItemIdentifiers = children.map { NSFileProviderItemIdentifier($0.identifier) }
        Self.keepDownloadedQueue.push(childItemIdentifiers)
    }
}
