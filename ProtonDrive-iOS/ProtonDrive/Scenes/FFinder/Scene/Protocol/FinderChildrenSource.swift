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

import Combine
import CoreData
import Foundation
@preconcurrency import PDCore

/// Provides the source of children for a finder scene and the scene-specific way to refresh them.
///
/// Folder uses paged children fetching; Trash will call `scanAllTrashed`; SharedWithMe will use
/// its own subscription. Each implementation owns the `FetchedObjectsObserver<Node>` and the
/// behavior of `fetchAllChildren` / `fetchNextPage`.
@MainActor
protocol FinderChildrenSource: AnyObject, ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var childrenObserver: FetchedObjectsObserver<Node> { get }
    /// Is fetching data
    var isFetching: Bool { get }
    /// Last updated time
    var lastUpdated: Date { get }
    /// Whether `fetchNextPage` is meaningful for this scene (drives `didScrollToBottom`).
    var supportsPaging: Bool { get }
    /// Refresh strategy used by `FFinderViewModel.fetchPages()`.
    var refreshMode: RefreshMode { get }

    /// Begin observing the children FRC.
    func start()

    func fetchPages() async throws

    /// Re-subscribe the children FRC after a sort preference change.
    func resubscribe(sorting: SortPreference) async throws

    /// Fetch every page of children from the remote source.
    func fetchAllChildren() async throws

    /// Fetch the next page; no-op for non-paging scenes.
    func fetchNextPage() async throws

    /// Cancel any in-flight remote requests (e.g. on view disappear).
    func cancelRequests() async
}
