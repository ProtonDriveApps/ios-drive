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

public protocol TreeDumpInteractor {
    func dump(tree: Tree) async throws -> String
}

final class ConcreteTreeDumpInteractor: TreeDumpInteractor {
    private let dumper: HierarchyDumper<TreeDumpProvider>

    init(dumper: HierarchyDumper<TreeDumpProvider>) {
        self.dumper = dumper
    }

    func dump(tree: Tree) async throws -> String {
        let provider = TreeDumpProvider(node: tree.root)
        return try await dumper.dump(root: provider)
    }
}
