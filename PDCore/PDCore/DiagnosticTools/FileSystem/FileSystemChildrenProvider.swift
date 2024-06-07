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

final class FileSystemChildrenProvider: ChildrenProvider {
    var fileManager: FileManager
    
    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }
    
    func children(_ node: URL, decryptor: FileSystemNodeDecryptor) async throws -> [FileSystemNodeProvider] {
        guard let enumerator = fileManager.enumerator(at: node, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
            return []
        }
        
        return enumerator.allObjects
            .compactMap { $0 as? URL }
            .map {
                FileSystemNodeProvider(
                    node: $0,
                    decryptor: decryptor,
                    childrenProvider: self
                )
            }
    }
}
