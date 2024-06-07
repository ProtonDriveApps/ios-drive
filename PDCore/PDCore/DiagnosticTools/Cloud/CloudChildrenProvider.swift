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

final class CloudChildrenProvider: ChildrenProvider {
    let shareID: String
    let client: Client

    init(shareID: String, client: Client) {
        self.shareID = shareID
        self.client = client
    }
    
    func children(_ node: Link, decryptor: CloudNodeDecryptor) async throws -> [CloudNodeProvider] {
        guard node.folderProperties != nil else {
            return []
        }
        
        return try await client.folderChildrenPages(shareID, folderID: node.linkID)
            .reduce(into: []) {
                $0.append(contentsOf: $1)
            }
            .map {
                CloudNodeProvider(
                    node: $0,
                    decryptor: decryptor,
                    childrenProvider: self
                )
            }
    }
}
