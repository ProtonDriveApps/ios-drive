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
import PDCore
import PDClient

actor FolderChildrenFetcher: Sendable {
    enum FetchMode { case idle, fetchingAll, fetchingPage }
    
    let dependencies: Dependencies
    let state: State
    private var mode: FetchMode = .idle
    private var nextPage: Int = 0
    private var fetchTask: Task<Bool, Error>?
    
    init(dependencies: Dependencies, state: State) {
        self.dependencies = dependencies
        self.state = state
    }
    
    func resetFetchedPage() throws {
        guard mode == .idle else { throw NodesFetchingErrors.busy }
        nextPage = 0
    }
    
    /// Fetch all folder children from the remote source
    func fetchAllChildren() async throws {
        guard mode == .idle else { throw NodesFetchingErrors.busy }
        mode = .fetchingAll
        let task = Task {
            let context = dependencies.storageManager.synchronousContextPool.acquire()
            defer { dependencies.storageManager.synchronousContextPool.relinquish(context) }
            
            while true {
                try Task.checkCancellation()
                let page = nextPage
                let isLast = try await fetchChildren(page: page, context: context)
                nextPage += 1
                if isLast { break }
            }
            return true
        }
        fetchTask = task
        defer {
            fetchTask = nil
            mode = .idle
        }
        _ = try await task.value
    }
    
    /// - Returns: Is last page
    @discardableResult
    func fetchNextPage() async throws -> Bool {
        guard mode == .idle else { throw NodesFetchingErrors.busy }
        mode = .fetchingPage
        let task = Task {
            let context = dependencies.storageManager.synchronousContextPool.acquire()
            defer { dependencies.storageManager.synchronousContextPool.relinquish(context) }
            
            try Task.checkCancellation()
            let page = nextPage
            let isLastPage = try await fetchChildren(page: page, context: context)
            nextPage += 1
            return isLastPage
        }
        fetchTask = task
        defer {
            fetchTask = nil
            mode = .idle
        }
        return try await task.value
    }
    
    /// Cancel on dismiss
    func cancelRequests() {
        fetchTask?.cancel()
        fetchTask = nil
    }
    
    /// Fetch the nth page of child nodes
    /// - Parameters:
    ///   - page: nth page
    /// - Returns: is last page
    private func fetchChildren(page: Int, context: NSManagedObjectContext) async throws -> Bool {
        guard let cloud = dependencies.cloudSlot else {
            assert(false, NodesFetchingErrors.noCloudInjected.localizedDescription)
            throw NodesFetchingErrors.noCloudInjected
        }
        let nodeID = state.nodeID
        
        var params: [FolderChildrenEndpointParameters] = [
            .page(page),
            .pageSize(state.pageSize),
        ]
        let sortPreference = dependencies.localSettings.nodesSortPreference
        if let sorting = sortPreference.apiSorting {
            params.append(.sortBy(sorting))
            params.append(.order(sortPreference.apiOrder))
        }
        let children = try await cloud.scanChildren(of: nodeID, parameters: params, moc: context)
        Log.info("Fetched \(nodeID), page: \(page), children: \(children.count)", domain: .networking)
        let isLastPage = children.count < state.pageSize
        if isLastPage {
            await context.perform { [context] in
                let node = CoreDataFolder.fetch(identifier: nodeID, in: context)
                node?.isChildrenListFullyFetched = true
                try? context.saveOrRollback()
            }
        }
        return isLastPage
    }
}

extension FolderChildrenFetcher {
    struct Dependencies {
        let cloudSlot: CloudSlotProtocol?
        let localSettings: LocalSettings
        let storageManager: StorageManager
    }
    
    struct State {
        let nodeID: NodeIdentifier
        let pageSize: Int
        
        init(
            nodeID: NodeIdentifier,
            pageSize: Int = PDCore.Constants.pageSizeForChildrenFetchAndEnumeration
        ) {
            self.nodeID = nodeID
            self.pageSize = pageSize
        }
    }
}
