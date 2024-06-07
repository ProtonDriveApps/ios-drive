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

extension File {
    /// Change the local state of file that are uploading. Files that are already commited cannot become uploading.
    /// The same logic applies to photos and photos with children
    func changeUploadingState(to newState: File.State) {
        guard let moc = moc else {
            return
        }
        
        moc.performAndWait {
            guard let state = state,
                  !committedStates.contains(state) else {
                return
            }
            self.state = newState
            try? moc.saveIfNeeded()
        }
    }
}

extension File {
    var committedStates: [Node.State] {
        [.active, .deleted, .deleting]
    }

    /// A file that is in a non committed/post-commited state
    @objc var isPendingUpload: Bool {
        guard let state = state else { return false }
        return !committedStates.contains(state)
    }
}

extension Photo {
    /// A photo that is in a non committed/post-commited  state as well as all of it's children photos.
    @objc override var isPendingUpload: Bool {
        let isSelfInNonCommittedState = super.isPendingUpload
        
        if isSelfInNonCommittedState {
            return true
        }
        
        // Check if all children are in a non-committed state
        let areChildrenInNonCommittedState = children.allSatisfy { $0.isPendingUpload }
        
        return isSelfInNonCommittedState || areChildrenInNonCommittedState
    }
}
