// Copyright (c) 2024 Proton AG
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

public struct FolderChildrenPages: AsyncSequence {
    public typealias Element = [Link]
    public typealias Parameters = FolderChildrenEndpointParameters
    
    let pageSize: Int
    let folderID: String
    let shareID: String
    let otherParameters: [Parameters]
    let client: Client
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(pageSize: pageSize, folderID: folderID, shareID: shareID, otherParameters: otherParameters, client: client)
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        
        let pageSize: Int
        let folderID: String
        let shareID: String
        let otherParameters: [Parameters]
        let client: Client
        
        var currentPage = 0
        var hasMore = true
        
        public mutating func next() async throws -> [Link]? {
            guard !Task.isCancelled else {
                return nil
            }
            
            guard hasMore else {
                return nil
            }
            
            let nodes = try await client.getFolderChildren(
                shareID, 
                folderID: folderID,
                parameters: otherParameters + [.page(currentPage), .pageSize(pageSize)]
            )
            
            currentPage += 1
            hasMore = nodes.count == pageSize
            return nodes
        }
    }
}
