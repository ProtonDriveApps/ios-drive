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

// To migrate an existing Photo-Share in a Standard-Volume to a Photo-Volume
struct MigratePhotoShareRequest: Endpoint {
    typealias Response = CodeResponse

    let request: URLRequest

    init(service: APIService, credential: ClientCredential) throws {
        self.request = try RequestFactory().make(
            method: .post,
            path: "/photos/migrate-legacy",
            service: service,
            credential: credential
        )
    }
}
