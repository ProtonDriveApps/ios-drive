// Copyright (c) 2026 Proton AG
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

public struct FolderChildrenListV2Response: Codable {
    public let linkIDs: [String]
    public let anchorID: String?
    public let more: Bool
    public let code: Int

    public init(linkIDs: [String], anchorID: String?, more: Bool, code: Int) {
        self.linkIDs = linkIDs
        self.anchorID = anchorID
        self.more = more
        self.code = code
    }
}

/// Lists a folder's children link IDs for the v2 scan. Includes trashed children.
/// `FoldersOnly=1` returns only subfolder IDs; `FoldersOnly=0` returns all children IDs.
/// - GET: /drive/v2/volumes/{volumeID}/folders/{linkID}/children?AnchorID=&FoldersOnly=
public struct FolderChildrenListV2Endpoint: Endpoint {
    public typealias Response = FolderChildrenListV2Response

    public let request: URLRequest

    public init(
        service: APIService,
        credential: ClientCredential,
        volumeID: String,
        folderID: String,
        anchorID: String?,
        foldersOnly: Bool
    ) {
        var queries: [URLQueryItem] = []
        if let anchorID {
            queries.append(URLQueryItem(name: "AnchorID", value: anchorID))
        }
        queries.append(URLQueryItem(name: "FoldersOnly", value: foldersOnly ? "1" : "0"))

        let url = service.url(of: "/v2/volumes/\(volumeID)/folders/\(folderID)/children", queries: queries)

        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        self.request = request
    }
}
