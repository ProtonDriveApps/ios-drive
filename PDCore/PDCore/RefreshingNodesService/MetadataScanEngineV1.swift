// Copyright (c) 2026 Proton AG
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
import Dispatch
import Foundation

/// v1 metadata scan: recurses the tree via the downloader and counts settled nodes.
final class MetadataScanEngineV1: MetadataScanEngine {
    private let downloader: Downloader
    private let reporter: FullResyncMetricsReporting

    init(downloader: Downloader, reporter: FullResyncMetricsReporting) {
        self.downloader = downloader
        self.reporter = reporter
    }

    // `resume` is unused: v1 resumes implicitly via the recovery store's isChildrenListFullyFetched flags
    // (scanTrees runs with skipFullyFetchedFolders), so a preserved recovery DB is enough to continue.
    // `volumeID` is unused too: v1 scans via the share/link endpoints, not the volume endpoints.
    func scanMetadata(
        root: Folder,
        volumeID: String,
        resume: Bool,
        cancelToken: CancelToken?,
        onNodesRefreshed: @MainActor @escaping (_ saved: Int, _ total: Int?) -> Void
    ) async throws -> RefreshedNodesReport {
        // The downloader's OperationQueue runs up to 6 enumeration callbacks concurrently,
        // so the counters must be serialized and Core Data reads must happen on the node's context queue.
        let counterLock = NSLock()
        var totalNodeCount = 0
        var activeNodeCount = 0
        let enumeration: Downloader.NodesEnumeration = { moc, nodes in
            guard !nodes.isEmpty else { return }
            // One context pass per batch (a folder's sibling files, or a single folder), instead of one per
            // node. Count only settled nodes — a folder once its own listing is complete; files are already
            // only enumerated after their parent's listing completes — so the count stays stable on resume.
            let (settledCount, activeCount): (Int, Int) = moc.performAndWait {
                var settled = 0
                var active = 0
                for node in nodes {
                    let isSettled = (node as? Folder)?.isChildrenListFullyFetched ?? true
                    guard isSettled else { continue }
                    settled += 1
                    if node.state == .active && !node.isTrashInheriting { active += 1 }
                }
                // Fault finished files to bound memory: a file is a saved leaf, never re-read and never an
                // ancestor for isTrashInheriting, so it's dead after this count. Folders stay live as ancestors.
                for node in nodes where node is File {
                    moc.refresh(node, mergeChanges: false)
                }
                return (settled, active)
            }

            guard settledCount > 0 else { return }

            counterLock.lock()
            totalNodeCount += settledCount
            activeNodeCount += activeCount
            let currentTotal = totalNodeCount
            counterLock.unlock()

            Log.debug("[Sync] Scanned \(settledCount) settled nodes (\(activeCount) active)", domain: .syncing)
            Task { @MainActor in
                onNodesRefreshed(currentTotal, nil)
            }
        }

        // Sync only needs the enumeration counts, so don't retain every scanned node in the returned
        // array — letting the context release saved nodes during the run.
        let scanStarted = DispatchTime.now()
        do {
            _ = try await downloader.scanTrees(
                treesRootFolders: [root], enumeration: enumeration, cancelToken: cancelToken,
                configuration: .init(
                    shouldIncludeDeletedItems: true,
                    collectScannedNodes: false,
                    skipFullyFetchedFolders: true,
                    resumePartialFoldersFromLastPage: true
                )
            )
        } catch {
            // A stop mid-scan (pause / cancel / fatal) still reports how far the fetch got, at what speed.
            counterLock.lock()
            let partialTotal = totalNodeCount
            counterLock.unlock()
            reporter.reportSpeed(step: .metadataFetch, engine: .v1, nodeCount: partialTotal, elapsed: Self.elapsedSeconds(since: scanStarted))
            throw error
        }
        counterLock.lock()
        let finalTotal = totalNodeCount
        let finalActive = activeNodeCount
        counterLock.unlock()
        reporter.reportSpeed(step: .metadataFetch, engine: .v1, nodeCount: finalTotal, elapsed: Self.elapsedSeconds(since: scanStarted))
        return RefreshedNodesReport(active: finalActive, total: finalTotal)
    }

    private static func elapsedSeconds(since start: DispatchTime) -> TimeInterval {
        Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }
}
