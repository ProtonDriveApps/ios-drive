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

import PDCore
import FileProvider
import Foundation
import ProtonCoreUtilities

struct ContentVersion: Codable, Hashable {
    // A unique hash between any changes to an item
    let versionHash: Data

    private init(versionHash: Data) {
        self.versionHash = versionHash
    }

    init(node: Node) {
        // This logic is a workaround until BE will return activeRevision ID on GET /shares/ID/folders/ID/children endpoint:
        // node is File and has more than one revision in local metadata DB -> need to bump verison to id of active revision
        guard let file = node as? File, let activeRevision = file.activeRevision else {
            self.versionHash = Data()
            return
        }

        guard !MimeType(value: node.mimeType).isProtonFile else {
            // Overwrites local edits with empty content, since the filesystem
            // only updates it's content if the content version changes
            self.versionHash = ItemVersionHasher.hash(for: UUID().uuidString)
            return
        }

        // Otherwise we can just use activeRevision ID to distinguish from previous revisions
        self.versionHash = ItemVersionHasher.hash(for: activeRevision.id)
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
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(self)
        } catch {
            fatalError("Failed to encode content version")
        }
    }
}
