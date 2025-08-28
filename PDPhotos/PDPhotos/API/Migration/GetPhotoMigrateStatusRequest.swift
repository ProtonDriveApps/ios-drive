// Copyright (c) 2024 Proton AG
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

enum PhotoMigrateStatus {
    /// Trigger an async task that handles the migration.
    case scheduled
    /// The migration is already in progress
    case inProgress
    /// The migration is already in progress, or already done, call GetPhotoMigrateStatusRequest to check
    case inProgressOrDone
    /// The client must then create a new Photo-Volume via the Create Photo Volume endpoint after this migration is complete.
    case needsToCreateNewShare(oldeVolumeID: String)
    case done(oldeVolumeID: String, newVolumeID: String)
    // TODO:albums: When backend ready, check what are other possible cases
    case unknown
}

struct GetPhotoMigrateStatusRequest: Endpoint {
    typealias Response = GetPhotoMigrateStatusResponse

    let request: URLRequest

    init(service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .get,
            path: "/photos/migrate-legacy",
            service: service,
            credential: credential
        )
    }
}

struct GetPhotoMigrateStatusResponse: Codable {
    let code: Int
    let oldVolumeID: String
    let newVolumeID: String?
}
