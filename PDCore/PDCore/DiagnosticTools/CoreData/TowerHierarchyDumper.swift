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

public struct TowerHierarchyDumper {
    public init() { }
    
    public func dump(tower: Tower, sorter: @escaping NodeProviderNameSorter, obfuscator: @escaping NodeProviderNameObfuscator) async throws -> String {
        
        guard let rootId = tower.rootFolderIdentifier(),
              let root = tower.folderForNodeIdentifier(rootId) else
        {
            throw NSError(domain: "TowerHierarchyDumper", code: 1)
        }
        
        let dumper = HierarchyDumper<CoreDataNodeProvider>(nameObfuscator: obfuscator, childSorter: sorter)
        let decryptor = CoreDataNodeDecryptor()
        let childrenProvider = CoreDataChildrenProvider(moc: root.moc!)
        let provider = CoreDataNodeProvider(
            node: root,
            decryptor: decryptor,
            childrenProvider: childrenProvider
        )
        let output = try await dumper.dump(root: provider)
        return output
    }
}
