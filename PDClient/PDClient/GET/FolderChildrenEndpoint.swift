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

public enum FolderChildrenEndpointParameters {
    public enum SortField: String {
        case mimeType = "MIMEType", size = "Size", modified = "ModifyTime"
    }
    public enum SortOrder: Int {
        case asc = 0, desc = 1
    }
    
    case page(Int)
    case pageSize(Int)
    case showAll
    case withKeys
    case sortBy(SortField)
    case order(SortOrder)
    case thumbnails
    
    var queryItem: URLQueryItem {
        switch self {
        case .page(let count):
            return .init(name: "Page", value: "\(count)")
        case .pageSize(let size):
            return .init(name: "PageSize", value: "\(size)")
        case .showAll:
            return .init(name: "ShowAll", value: "1")
        case .withKeys:
            return .init(name: "Keys", value: "1")
        case .sortBy(let field):
            return .init(name: "Sort", value: field.rawValue)
        case .order(let order):
            return .init(name: "Desc", value: "\(order.rawValue)")
        case .thumbnails:
            return .init(name: "Thumbnails", value: "1")
        }
    }
}

public struct FolderChildrenEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        var links: [Link]
        
        public init(code: Int, links: [Link]) {
            self.code = code
            self.links = links
        }
    }
    
    public var request: URLRequest
    
    init(shareID: Share.ShareID, folderID: Link.LinkID, parameters: [FolderChildrenEndpointParameters]? = nil, service: APIService, credential: ClientCredential) {
        // url
        let queryItems = parameters?.map(\.queryItem)
        
        var url = service.url(of: "/shares", parameters: queryItems)
        url.appendPathComponent(shareID)
        url.appendPathComponent("/folders")
        url.appendPathComponent(folderID)
        url.appendPathComponent("/children")
        
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        self.request = request
    }
}

extension Array where Element == FolderChildrenEndpointParameters {
    public func containsPagination() -> Bool {
        self.contains { param -> Bool in
            if case FolderChildrenEndpointParameters.page = param {
                return true
            } else {
                return false
            }
        }
    }
}
