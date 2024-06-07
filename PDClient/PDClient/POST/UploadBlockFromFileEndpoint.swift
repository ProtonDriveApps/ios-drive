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

public struct UploadBlockFromFileEndpoint: Endpoint {
    public struct Response: Codable {
        var code: Int
    }
    
    public private(set) var boundary: String
    public private(set) var request: URLRequest
    public private(set) var onDiskUrl: URL
    
    public static func prefix(boundary: String) -> Data {
        var data = Data()
        data.append(Data("\r\n--\(boundary)\r\n".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"Block\"; filename=\"blob\"\r\n".utf8))
        data.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        return data
    }
    
    public static func suffix(boundary: String) -> Data {
        Data("\r\n--\(boundary)--\r\n".utf8)
    }
    
    public static func writeDataToIntermediateFile(boundary: String, dataUrl: URL, chunkSize: Int) throws -> (intermediate: URL, contentLength: UInt64) {
        // open
        let copy = dataUrl.appendingPathExtension("upload")
        if FileManager.default.fileExists(atPath: copy.path) {
            try FileManager.default.removeItem(at: copy)
        }
        FileManager.default.createFile(atPath: copy.path, contents: Data(), attributes: nil)
        let writeHandle = try FileHandle(forWritingTo: copy)
        defer { try? writeHandle.close() }
        
        // prefix
        try writeHandle.write(contentsOf: Self.prefix(boundary: boundary))
        
        // data to upload
        let reader = try FileHandle(forReadingFrom: dataUrl)
        defer { try? reader.close() }
        var data = try reader.read(upToCount: chunkSize) ?? Data()
        while !data.isEmpty {
            try autoreleasepool {
                try writeHandle.write(contentsOf: data)
                data = try reader.read(upToCount: chunkSize) ?? Data()
            }
        }
        
        // suffix
        try writeHandle.write(contentsOf: Self.suffix(boundary: boundary))
        
        // close
        let contentLength = try writeHandle.offset()
        return (copy, contentLength)
    }
    
    public init(url: URL, data dataUrl: URL, chunkSize: Int, credential: ClientCredential, service: APIService) throws {
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        self.boundary = UUID().uuidString
        let (intermediate, contentLength) = try Self.writeDataToIntermediateFile(boundary: boundary, dataUrl: dataUrl, chunkSize: chunkSize)
        
        // headers
        var headers = service.baseHeaders
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        headers["Content-Length"] = "\(contentLength)"
        headers["Accept-Encoding"] = "gzip, deflate, br"
        headers["Accept"] = "*/*"
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        self.onDiskUrl = intermediate
        self.request = request
    }
}
