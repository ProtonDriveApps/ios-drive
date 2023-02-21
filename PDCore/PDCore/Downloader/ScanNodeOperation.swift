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

import Foundation
import PDClient

class ScanNodeOperation: SynchronousOperation {
    typealias Completion = (Result<[Node], Error>) -> Void
    
    private var nodeID: NodeIdentifier
    private weak var cloudSlot: CloudSlot?
    private var completion: Completion?
    
    private var lastFetchedPage: Int = 0
    private var pageSize: Int = 150
    
    init(_ nodeID: NodeIdentifier,
         cloudSlot: CloudSlot,
         completionHandler: @escaping Completion)
    {
        self.nodeID = nodeID
        self.cloudSlot = cloudSlot
        self.completion = completionHandler
        
        super.init()
    }
    
    override func cancel() {
        self.completion = nil
        super.cancel()
        
        ConsoleLogger.shared?.log("Scan children operation cancelled for node \(self.nodeID.nodeID)", osLogType: OfflineSaver.self)
    }
    
    override func start() {
        super.start()
        guard !self.isCancelled else { return }
        
        self.cloudSlot?.scanNode(self.nodeID) { [weak self] nodeResult in
            guard let self = self, !self.isCancelled else { return }
            switch nodeResult {
            case let .failure(error):
                ConsoleLogger.shared?.log(error, osLogType: OfflineSaver.self)
                self.completion?(.failure(error))
                self.state = .finished
                
            case let .success(node as Folder):
                ConsoleLogger.shared?.log("Start fetching pages for node \(self.nodeID.nodeID)", osLogType: OfflineSaver.self)
                self.fetchChildrenFromAPI(node)
                
            default: assert(false, "Should not scan File nodes in this operation")
            }
        }
    }
    
    // Similar functionality is also implemented in iOS app's NodesFetching model
    // usage of this technique is discouraged because recursive fetching is a heavy operation
    private func fetchChildrenFromAPI(_ node: Folder) {
        guard !self.isCancelled else { return }
        let params: [FolderChildrenEndpointParameters] = [
            .page(self.lastFetchedPage),
            .pageSize(self.pageSize)
        ]
        
        self.cloudSlot?.scanChildren(of: self.nodeID, parameters: params) { [weak self] resultChildren in
            guard let self = self, !self.isCancelled else { return }
            
            switch resultChildren {
            case let .failure(error):
                ConsoleLogger.shared?.log(error, osLogType: OfflineSaver.self)
                self.completion?(.failure(error))
                self.state = .finished
                
            case let .success(nodes) where nodes.count < self.pageSize:
                // this is last page
                ConsoleLogger.shared?.log("Fetched page #\(self.lastFetchedPage) last (\(nodes.count) nodes) children for node \(self.nodeID.nodeID)", osLogType: OfflineSaver.self)
                node.managedObjectContext?.performAndWait {
                    node.isChildrenListFullyFetched = true
                    try? node.managedObjectContext?.save()
                }
                
                // return not `nodes` that we got for last page, but children from all pages
                self.completion?(.success(Array(node.children)))
                self.state = .finished
                
            case .success:
                // this is not last page and need to request next one
                ConsoleLogger.shared?.log("Fetched page #\(self.lastFetchedPage) full (\(self.pageSize) nodes) for node \(self.nodeID.nodeID)", osLogType: OfflineSaver.self)
                self.lastFetchedPage += 1
                return self.fetchChildrenFromAPI(node)
            }
        }
    }
}
