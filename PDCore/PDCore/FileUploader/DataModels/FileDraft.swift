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
public class FileDraft: Equatable {

    /// Initial state of the file
    public let state: State

    /// Number of blocks that the active revision draft has or will have
    public let numberOfBlocks: Int

    /// Unique Identifier for the uploading file
    public let uploadID: UUID

    /// Backing CoreData file
    public let file: File

    public init(uploadID: UUID, file: File, state: FileDraft.State, numberOfBlocks: Int) {
        self.uploadID = uploadID
        self.file = file
        self.state = state
        self.numberOfBlocks = numberOfBlocks
    }

    var isEmpty: Bool {
        numberOfBlocks == .zero
    }

    public static func == (lhs: FileDraft, rhs: FileDraft) -> Bool {
        lhs === rhs
    }
}
