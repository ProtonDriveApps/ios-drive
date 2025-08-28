// Copyright (c) 2025 Proton AG
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

// Empty volume trash
// POST: /volumes/{volumeID}/trash
struct EmptyVolumeTrashEndpoint: Endpoint {
    typealias Response = CodeResponse

    var request: URLRequest

    init(volumeId: Volume.VolumeID, service: APIService, credential: ClientCredential) {
        var url = service.url(of: "/volumes")
        url.appendPathComponent(volumeId)
        url.appendPathComponent("/trash")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        self.request = request
    }
}
