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

actor HierarchyDumper<NoPr: NodeProvider> {
    let nameObfuscator: NodeProviderNameObfuscator
    let childSorter: NodeProviderNameSorter
    
    init(nameObfuscator: @escaping NodeProviderNameObfuscator,
         childSorter: @escaping NodeProviderNameSorter
    ) {
        self.nameObfuscator = nameObfuscator
        self.childSorter = childSorter
    }
    
    func dump(root: NoPr) async throws -> String {
        try await dumpSubtree(under: root, prefix: "", isLast: true)
    }
    
    private func dumpSubtree(under node: NoPr, prefix: String, isLast: Bool) async throws -> String {
        let connector = isLast ? "└" : "├"
        let step = isLast ? "∙    " : "│    "

        var output = prefix + connector + dumpNode(node.interface()) + "\n"
        
        let children = try await node.children(sorted: childSorter)
        for i in children.indices {
            output += try await dumpSubtree(under: children[i], prefix: prefix + step, isLast: i == children.endIndex - 1)
        }
        
        return output
    }
    
    private func dumpNode(_ node: NodeInterface) -> String {
        var badge = node.label
        if !badge.isEmpty {
            badge = "-[" + badge + "]-"
        } else {
            badge = "-"
        }
        let type = node.isFolder ? "📁 " : " "
        return badge + type + node.name(nameObfuscator: nameObfuscator)
    }
}
