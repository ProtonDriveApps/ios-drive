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
import ProtonCoreNetworking

// GET api/core/v4/features/{code}
// There's another endpoint to retrieve legacy FF lists.
// If there are additional legacy FFs, please migrate them to that endpoint.
// This endpoint can be more flexible, but for now, as the only legacy FF.
// It's hardcoded to simplify the implementation.
final class GetLegacyRatingIOSEndpoint: Request {
    var path: String = "/core/v4/features/RatingIOSDrive"
}

final class GetLegacyRatingIOSResponse: Decodable {
    let code: Int
    let feature: Feature
}

extension GetLegacyRatingIOSResponse {
    struct Feature: Decodable {
        let value: Bool
    }
}
