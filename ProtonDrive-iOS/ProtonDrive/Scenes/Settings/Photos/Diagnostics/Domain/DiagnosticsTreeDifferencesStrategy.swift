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

struct TreeDifferences: Equatable {
    struct Change: Equatable, Hashable {
        let index: Int?
        let title: String
    }

    let changes: [Change]
}

protocol DiagnosticsTreeDifferencesStrategy {
    func compare(lhs: Tree, rhs: Tree) -> TreeDifferences
}

final class ConcreteDiagnosticsTreeDifferencesStrategy: DiagnosticsTreeDifferencesStrategy {

    func compare(lhs: Tree, rhs: Tree) -> TreeDifferences {
        let diffInLhs = Set(lhs.root.descendants).subtracting(rhs.root.descendants).map { $0.title }
        let diffInRhs = Set(rhs.root.descendants).subtracting(lhs.root.descendants).map { $0.title }
        let bothDiffs = Set(diffInLhs + diffInRhs)
        let changes = bothDiffs.map { item in
            TreeDifferences.Change(index: lhs.root.descendants.firstIndex(where: { item == $0.title }), title: item)
        }
        let orderedChanges = changes.sorted(by: { ($0.index ?? Int.max) < ($1.index ?? Int.max) })
        return TreeDifferences(changes: orderedChanges)
    }
}
