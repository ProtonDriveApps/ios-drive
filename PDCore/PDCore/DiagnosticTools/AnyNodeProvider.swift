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

public typealias NodeProviderNameSorter = (String, String) -> Bool
public typealias NodeProviderNameObfuscator = (inout String) -> Void

protocol NodeProvider {
    associatedtype N
    associatedtype Decr
    associatedtype ChPr: ChildrenProvider where ChPr.Decr == Decr, ChPr.N == N, ChPr.NoPr == Self
    
    var node: N { get }
    var decryptor: Decr { get }
    var childrenProvider: ChPr { get }
    var decryptedName: String? { get }
    
    func interface() -> NodeInterface
    func children(sorted childrenSorter: NodeProviderNameSorter) async throws -> [Self]
}

extension NodeProvider {
    
    func children(sorted childrenSorter: NodeProviderNameSorter) async throws -> [Self] {
        try await childrenProvider
            .children(node, decryptor: decryptor)
            .sorted {
                childrenSorter($0.decryptedName ?? "", $1.decryptedName ?? "")
            }
    }
    
}
