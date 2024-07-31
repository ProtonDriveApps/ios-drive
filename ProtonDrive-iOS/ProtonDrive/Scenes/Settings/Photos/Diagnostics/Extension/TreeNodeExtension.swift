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
import PDCore

extension Tree.Node {
    public init(nodeTitle: String) {
        self.init(title: nodeTitle.normalizeIfGivenFileName())
    }

    public init(nodeTitle: String, descendants: [String]) {
        self.init(
            title: nodeTitle.normalizeIfGivenFileName(),
            descendants: descendants.map { $0.normalizeIfGivenFileName() }.sorted()
        )
    }

    public init(nodeTitle: String, descendants: [Tree.Node]) {
        self.init(
            title: nodeTitle.normalizeIfGivenFileName(),
            descendants: descendants.sorted(by: { $0.title < $1.title })
        )
    }
}

private extension String {
    func normalizeIfGivenFileName() -> String {
        let filename = fileName()
        let fileExtension = fileExtension()
        if fileExtension.isEmpty || fileExtension.containSymbol() {
            return self
        } else {
            return "\(filename).\(fileExtension.uppercased())"
        }
    }
    
    func containSymbol() -> Bool {
        let characterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return rangeOfCharacter(from: characterSet.inverted) != nil
    }
}
