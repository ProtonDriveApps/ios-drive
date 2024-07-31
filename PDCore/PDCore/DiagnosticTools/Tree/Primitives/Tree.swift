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

public struct Tree {
    public let root: Node

    public init(root: Node) {
        self.root = root
    }

    public struct Node: Equatable, Hashable {
        public let title: String
        public let descendants: [Node]

        public init(title: String) {
            self.title = title
            descendants = []
        }

        public init(title: String, descendants: [String]) {
            self.title = title
            self.descendants = descendants.map { Node(title: $0) }
        }

        public init(title: String, descendants: [Node]) {
            self.title = title
            self.descendants = descendants
        }
    }
}
