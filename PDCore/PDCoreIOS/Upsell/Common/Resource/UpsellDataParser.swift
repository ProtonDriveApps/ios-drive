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

protocol UpsellDataParserProtocol {
    func parse(_ payload: String) -> UpsellDataV1?
}

final class UpsellDataParser: UpsellDataParserProtocol {
    private static let supportedSchemaVersion = 1

    func parse(_ payload: String) -> UpsellDataV1? {
        guard let data = payload.data(using: .utf8),
              let upsellData = try? JSONDecoder.default.decode(UpsellDataV1.self, from: data),
              upsellData.schemaVersion == Self.supportedSchemaVersion else {
            return nil
        }
        return upsellData
    }
}
