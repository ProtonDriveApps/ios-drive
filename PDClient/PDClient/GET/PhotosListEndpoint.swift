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

public struct PhotosListEndpoint: Endpoint {
    public let request: URLRequest
    public typealias Response = PhotosListResponse

    public init(service: APIService, credential: ClientCredential, parameters: PhotosListRequestParameters) {
        var items = [URLQueryItem(name: "PageSize", value: "\(parameters.pageSize)")  ]
        if let lastId = parameters.lastId {
            let item = URLQueryItem(name: "PreviousPageLastLinkID", value: lastId)
            items.append(item)
        }

        let url = service.url(of: "/volumes/\(parameters.volumeId)/photos", parameters: items)
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        self.request = request
    }
}
