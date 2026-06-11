// Copyright (c) 2025 Proton AG
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

public protocol NodeTreeActionPerformer {
    func cast(nodes: [Node]) -> ([CoreDataFile], [CoreDataFolder], [CoreDataPhoto])
    func children(from parent: CoreDataFolder) -> ([CoreDataFile], [CoreDataFolder])
}

extension NodeTreeActionPerformer {
    public func cast(nodes: [Node]) -> ([CoreDataFile], [CoreDataFolder], [CoreDataPhoto]) {
        let files = nodes.compactMap { $0 as? CoreDataFile }
        let folders = nodes.compactMap { $0 as? CoreDataFolder }
        let photos = nodes.compactMap { $0 as? CoreDataPhoto }
        return (files, folders, photos)
    }

    public func children(from parent: CoreDataFolder) -> ([CoreDataFile], [CoreDataFolder]) {
        let files = parent.children.compactMap { $0 as? CoreDataFile }
        let folders = parent.children.compactMap { $0 as? CoreDataFolder }
        return (files, folders)
    }
}
