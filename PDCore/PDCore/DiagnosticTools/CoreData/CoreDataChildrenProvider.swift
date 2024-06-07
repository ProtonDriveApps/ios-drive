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
import CoreData

final class CoreDataChildrenProvider: ChildrenProvider {
    var moc: NSManagedObjectContext
    
    init(moc: NSManagedObjectContext) {
        self.moc = moc
    }
    
    func children(_ node: PDCore.Node, decryptor: CoreDataNodeDecryptor) async throws -> [CoreDataNodeProvider] {
        
        guard let folder = node as? Folder else {
            return []
        }
        
        return await moc.perform {
            folder.in(moc: self.moc).children.map {
                CoreDataNodeProvider(
                    node: $0,
                    decryptor: decryptor,
                    childrenProvider: self
                )
            }
        }
    }
}
