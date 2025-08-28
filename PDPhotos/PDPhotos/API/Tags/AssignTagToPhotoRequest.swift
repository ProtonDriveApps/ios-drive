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
import PDClient

/// Only the volume-owner can use this endpoint.
public struct AssignTagToPhotoRequest: Endpoint {
    public typealias Response = CodeResponse

    public let request: URLRequest

    public init(parameters: Parameters, service: APIService, credential: ClientCredential) throws {
        /// Assigning the “favorite” tag is not allowed through this endpoint
        assert(!parameters.body.tags.contains(.favorites))

        self.request = try RequestFactory().make(
            method: .post,
            path: "/photos/volumes/\(parameters.volumeID)/links/\(parameters.linkID)/tags",
            body: parameters.body,
            service: service,
            credential: credential
        )
    }
}

extension AssignTagToPhotoRequest {
    public struct Parameters {
        let volumeID: String
        let linkID: String
        let body: Body

        public struct Body: Codable {
            let tags: [PhotoTag]
        }
    }
}
