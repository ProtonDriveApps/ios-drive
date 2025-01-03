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

import Combine
import PDClient
import Foundation

public enum NodesFetchingErrors: Error {
    case noCloudInjected
    case objectIsReleased
}

public protocol NodesFetching: AnyObject {
    var tower: Tower! { get }
    var node: Folder  { get }
    var currentNodeID: NodeIdentifier! { get set }
    var pageSize: Int { get }
    var lastFetchedPage: Int { get set }
}

extension NodesFetching {
    public func prepareForRefresh(fromPage page: Int? = nil) {
        if let page = page {
            self.lastFetchedPage = page
        }
        // This may happen if logout was invoked by PMNetworking during this call
        // for example, if the session was closed on BE
        assert(self.node.managedObjectContext != nil)
        
        self.node.managedObjectContext?.performAndWait {
            self.currentNodeID = self.node.identifier
        }
    }
}

extension NodesFetching where Self: NodesSorting {
    // Similar functionality is also implemented in PDCore's ScanNodeOperation
    // usage of this technique is discouraged because recursive fetching is a heavy operation
    public func fetchChildrenFromAPI(proceedTillLastPage: Bool) -> AnyPublisher<(nodes: [Node], isLastPage: Bool), Error> {
        Future<[Node], Error> { [unowned self] promise in
            guard let cloud = self.tower.cloudSlot else {
                assert(false, NodesFetchingErrors.noCloudInjected.localizedDescription)
                return promise(.failure(NodesFetchingErrors.noCloudInjected))
            }
            var params: [FolderChildrenEndpointParameters] = [
                .page(self.lastFetchedPage),
                .pageSize(self.pageSize),
                .thumbnails,
            ]
            
            if let sort = self.sorting.apiSorting {
                params.append(.sortBy(sort))
                params.append(.order(self.sorting.apiOrder))
            }
            let parameters = params
            Task {
                do {
                    let children = try await cloud.scanChildren(of: self.currentNodeID, parameters: parameters)
                    promise(.success(children))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .flatMap { [weak self] nodes -> AnyPublisher<(nodes: [Node], isLastPage: Bool), Error> in
            guard let self else {
                return Fail(error: NodesFetchingErrors.objectIsReleased).eraseToAnyPublisher()
            }
            Log.info("Fetched page: \(self.lastFetchedPage)", domain: .networking)
            let isLastPage = nodes.count < self.pageSize
            if isLastPage {
                // this is last page
                self.node.managedObjectContext?.performAndWait {
                    self.node.isChildrenListFullyFetched = true
                    try? self.node.managedObjectContext?.saveOrRollback()
                }
                return Just((nodes: nodes, isLastPage: true)).setFailureType(to: Error.self).eraseToAnyPublisher()
            } else if proceedTillLastPage == false {
                // only one page requested
                self.lastFetchedPage += 1
                return Just((nodes: nodes, isLastPage: false)).setFailureType(to: Error.self).eraseToAnyPublisher()
            } else {
                // this is not last page and need to request next one
                self.lastFetchedPage += 1
                return self.fetchChildrenFromAPI(proceedTillLastPage: proceedTillLastPage)
            }
        }
        .eraseToAnyPublisher()
    }
}
