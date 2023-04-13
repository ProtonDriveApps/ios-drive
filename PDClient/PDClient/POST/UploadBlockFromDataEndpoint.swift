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

public struct UploadBlockFromDataEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
    }

    public private(set) var request: URLRequest
    
    public init(url: URL, data: inout Data, credential: ClientCredential, service: APIService) {
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString

        var multipartData = Data()
        multipartData.append(Data("\r\n--\(boundary)\r\n".utf8))
        multipartData.append(Data("Content-Disposition: form-data; name=\"Block\"; filename=\"blob\"\r\n".utf8))
        multipartData.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        multipartData.append(data)
        multipartData.append(Data("\r\n--\(boundary)--\r\n".utf8))

        // headers
        var headers = service.baseHeaders
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        headers["Content-Length"] = "\(multipartData.count)"
        headers["Accept-Encoding"] = "gzip, deflate, br"
        headers["Accept"] = "*/*"
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        data = multipartData
        self.request = request
    }
}
