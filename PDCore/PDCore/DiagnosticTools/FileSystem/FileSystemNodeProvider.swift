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

struct FileSystemNodeProvider: NodeProvider {
    typealias N = URL
    typealias Decr = FileSystemNodeDecryptor
    typealias ChPr = FileSystemChildrenProvider
    
    let node: N
    let decryptor: Decr
    let childrenProvider: ChPr
    let decryptedName: String?
    
    init(node: N,
         decryptor: Decr,
         childrenProvider: ChPr
    ) {
        self.node = node
        self.decryptor = decryptor
        self.childrenProvider = childrenProvider
        self.decryptedName = try? decryptor.decryptName(node)
    }
    
    func interface() -> NodeInterface {
        NodeInterface(isFolder: isFolder, label: label, decryptedName: decryptedName)
    }
    
    private var isFolder: Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: node.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
    
    private var label: String {
        if node.lastPathComponent.hasPrefix(".") {
            return "hidden"
        } else {
            return ""
        }
    }
}
