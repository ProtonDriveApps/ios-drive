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

import FileProvider
import Foundation

struct MetadataVersion: Codable {
    // For identifying uniqueness between important properties during conflict resolution
    let parentIdentifierHash: Data
    let filenameHash: Data

    init(item: NSFileProviderItem) {
        self.parentIdentifierHash = ItemVersionHasher.hash(for: item.parentItemIdentifier)
        self.filenameHash = ItemVersionHasher.hash(for: item.filename)
    }
    
    init?(from data: Data) {
        do {
            self = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            return nil
        }
    }

    func encoded() -> Data {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            fatalError("Failed to encode metadata version")
        }
    }
}
