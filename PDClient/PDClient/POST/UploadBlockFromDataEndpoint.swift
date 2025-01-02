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

        /*
         When appending directly to Data, the OS will reserve extra space on the
         assumption that you are going to be appending more afterwards.
         It does this to help avoid the need to realloc the underlying storage for each append.
         
         But if one of the parts being appended is 'large' the OS can overcompensate
         in its calculation for how much extra to reserve and it allocs a block
         much larger than we will need.
         
         In the case of uploading our max input data (currently 4MB) the OS reserves an extra ~1MB
         that we don't use, increasing our overall heap usage with no gain to us.
         
         So we prepare all the parts in an array first so we can determine how
         large a Data we need upfront.

         When multiple such Data are being prepared/uploaded simultaneously this change
         was shown to greatly reduce the high water mark of memory used.
        */
        var parts: [Data] = []
        parts.append(Data("\r\n--\(boundary)\r\n".utf8))
        parts.append(Data("Content-Disposition: form-data; name=\"Block\"; filename=\"blob\"\r\n".utf8))
        parts.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        // As Data is Copy on Write, there is no need to worry about using additional
        // heap space just to store the input data in the array.
        parts.append(data)
        parts.append(Data("\r\n--\(boundary)--\r\n".utf8))
        
        // Now we have all the parts ready we can calculate their total size
        let totalSize = parts.reduce(0) { $0 + $1.count }
        // and create a Data with that capacity before adding to it.
        var multipartData = Data(capacity: totalSize)
        parts.forEach { multipartData.append($0) }
        /*
         Even though we specified the capacity explicitly that is only a hint to the OS.
         It may adjust it upwards slightly to align to a specific memory boundary.
         Hence if you look in the debugger here you probably won't see the true
         capacity match our `totalSize`, but it should be a minor difference.
         */

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
