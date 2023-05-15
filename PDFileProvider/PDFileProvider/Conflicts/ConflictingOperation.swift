// Copyright (c) 2023 Proton AG
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

public indirect enum ConflictingOperation {
    case create(ConflictingOperation?)
    case edit(ConflictingOperation?)
    case move(ConflictingOperation?)
    case delete(parent: Bool)
    
        
    /* TODO: migrate to destinct cases
     // pseudo
    case createCreate
    case moveMove
    case editEdit
    case deleteDelete
     
     // name clash
    case createCreate
    case moveCreate
    case moveMoveDestination
     
     // edit conflict
    case editEdit
     
     // delete conflict
    case editDelete
    case editParentDelete
    case moveDelete
     
     // move conflict
    case moveMoveSource
     
     // indirect conflict
    case moveParentDeleteDestination
    case createParentDelete
    case moveMoveCycle
    */
}
