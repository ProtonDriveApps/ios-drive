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
import Foundation

/// Fetches a node's ancestor chain up to a known/saved ancestor and saves it parent-first.
protocol ScanNodeAncestorResolving {
    func resolveAncestors(linkIDs: [String], shareID: String, moc: NSManagedObjectContext) async throws
}

extension CloudSlot: ScanNodeAncestorResolving {
    func resolveAncestors(linkIDs: [String], shareID: String, moc: NSManagedObjectContext) async throws {
        try await scanNodes(linkIDs: linkIDs, shareID: shareID, moc: moc)
    }
}

/// Handles the rare case where a discovered node's fresh metadata points to a parent folder the scan never
/// discovered — the node was moved into a new/undiscovered folder.
protocol LateParentResolver {
    func resolve(unknownParentIDs: Set<String>) async throws
}

/// Resolves each unknown parent by saving its ancestor chain (so the child can be saved without a stub
/// parent that would fail Core Data validation), then discovering the parent's own subtree so its other
/// children are scanned too — which grows the total node count.
final class ScanLateParentResolver: LateParentResolver, @unchecked Sendable {
    private let ancestorResolver: ScanNodeAncestorResolving
    private let treeDiscoveryService: TreeDiscoveryService
    private let shareID: String
    private let moc: NSManagedObjectContext

    init(
        ancestorResolver: ScanNodeAncestorResolving,
        treeDiscoveryService: TreeDiscoveryService,
        shareID: String,
        moc: NSManagedObjectContext
    ) {
        self.ancestorResolver = ancestorResolver
        self.treeDiscoveryService = treeDiscoveryService
        self.shareID = shareID
        self.moc = moc
    }

    func resolve(unknownParentIDs: Set<String>) async throws {
        for parentID in unknownParentIDs.sorted() {
            // Save the parent and its ancestor chain, parent-first, so the child no longer references a stub.
            try await ancestorResolver.resolveAncestors(linkIDs: [parentID], shareID: shareID, moc: moc)
            // Discover the parent's subtree so its other children are scanned too. The depth base is
            // irrelevant to correctness: the parent is already saved, so only within-subtree order matters.
            try await treeDiscoveryService.discoverFiles(inside: UnlistedFolder(id: parentID, parentID: nil, depth: 0))
        }
    }
}
