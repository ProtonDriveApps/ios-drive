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
/// Removing a Tag from a Node that doesn’t actually contain said Tag will result in a success response anyway.
struct RemoveTagFromPhotoRequest: Endpoint {
    typealias Response = CodeResponse

    let request: URLRequest

    init(parameters: AssignTagToPhotoRequest.Parameters, service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .delete,
            path: "/photos/volumes/\(parameters.volumeID)/links/\(parameters.linkID)/tags",
            body: parameters.body,
            service: service,
            credential: credential
        )
    }
}
