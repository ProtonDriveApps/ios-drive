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

@preconcurrency import PDCore
import CoreData
import Foundation
import PDCoreIOS
import PDSDKCore
import ProtonCoreNetworking

/// `FinderChildrenSource` for a regular folder: paged children fetched via `FolderChildrenFetcher`,
/// FRC subscribed via `tower.uiSlot.subscribeToChildren`.
@MainActor
final class FolderChildrenSource: FinderChildrenSource {
    @Published private(set) var isFetching: Bool = false
    private let childrenFetcher: FolderChildrenFetcher
    private let context: NSManagedObjectContext
    private let folder: NodeDTO
    private let tower: Tower
    private let userMessageHandler: UserMessageHandlerProtocol
    private(set) var lastUpdated: Date = .distantPast

    let childrenObserver: FetchedObjectsObserver<Node>

    init(
        tower: Tower,
        folder: NodeDTO,
        childrenFetcher: FolderChildrenFetcher,
        userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
    ) {
        self.tower = tower
        self.folder = folder
        let pool = tower.storage.synchronousContextPool
        let context = pool.acquire()
        self.context = context
        self.childrenFetcher = childrenFetcher
        self.userMessageHandler = userMessageHandler

        let children = tower.uiSlot!.subscribeToChildren(
            of: folder.nodeIdentifier,
            sorting: tower.localSettings.nodesSortPreference,
            preferredContext: context
        )
        self.childrenObserver = FetchedObjectsObserver(children, onDeinit: {
            pool.relinquish(context)
        })
    }

    var supportsPaging: Bool {
        refreshMode == .fetchPageByRequest
    }

    var refreshMode: RefreshMode {
        switch tower.localSettings.nodesSortPreference {
        case .nameAscending, .nameDescending:
            return .fetchAllPages
        default:
            return Constants.childrenRefreshStrategy
        }
    }

    func start() {
        let observer = childrenObserver
        Task.detached {
            observer.start()
        }
    }

    func fetchPages() async throws {
        switch refreshMode {
        case .fetchAllPages where !isLoadedOrUpdating:
            try await fetchAllChildren()
        case .fetchPageByRequest where !isLoadedOrUpdating:
            try await fetchNextPage()
        case .events where !folder.isChildrenListFullyFetched:
            try await fetchAllChildren()
        case .events:
            lastUpdated = Date()
        default: break
        }
    }

    func resubscribe(sorting: SortPreference) async throws {
        let children = tower.uiSlot!.subscribeToChildren(
            of: folder.nodeIdentifier,
            sorting: sorting,
            preferredContext: context
        )
        childrenObserver.inject(fetchedResultsController: children)
        lastUpdated = .distantPast
        await cancelRequests()
        try await fetchPages()
    }

    func fetchAllChildren() async throws {
        if isFetching { return }
        isFetching = true
        defer { isFetching = false }
        tower.forcePolling(volumeIDs: [folder.id.volumeID])
        try await childrenFetcher.resetFetchedPage()
        try await childrenFetcher.fetchAllChildren()
        lastUpdated = Date()
    }

    func fetchNextPage() async throws {
        if isFetching { return }
        isFetching = true
        defer { isFetching = false }
        try await childrenFetcher.fetchNextPage()
        lastUpdated = Date()
    }

    func cancelRequests() async {
        await childrenFetcher.cancelRequests()
    }
}

extension FolderChildrenSource {
    private var isLoadedOrUpdating: Bool {
        lastUpdated != .distantPast || self.isFetching
    }
}
