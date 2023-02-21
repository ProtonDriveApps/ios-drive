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

struct ShareURLEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
        var shareURLs: [ShareURLMeta]
        var links: [Link.LinkID: Link]?
    }
    
    enum Parameters {
        case recursive
        case page(Int)
        case pageSize(Int)

        var queryItem: URLQueryItem {
            switch self {
            case .recursive:
                return .init(name: "Recursive", value: "1")
            case .page(let count):
                return .init(name: "Page", value: "\(count)")
            case .pageSize(let size):
                return .init(name: "PageSize", value: "\(size)")
            }
        }
    }
    
    var request: URLRequest
    
    init(shareID: Share.ShareID, parameters: [Parameters]? = nil, service: APIService, credential: ClientCredential) {
        let queryItems = parameters?.map(\.queryItem)
        
        // url
        var url = service.url(of: "/shares", parameters: queryItems)
        url.appendPathComponent(shareID)
        url.appendPathComponent("urls")
        
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
