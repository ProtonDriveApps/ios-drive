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
import CoreData

public class FileDraft: Equatable {

    /// Initial state of the file
    public let state: State

    /// Number of blocks that the active revision draft has or will have
    public let numberOfBlocks: Int

    /// Unique Identifier for the uploading file
    public let uploadID: UUID

    /// Backing CoreData file
    public let file: File

    /// CoreData object uri path
    public let uri: String

    /// file size in bytes
    private let size: Int

    var roundedKilobytes: Double {
        round(Double(size) / 1024)
    }

    let mimeType: MimeType

    public init(uploadID: UUID, file: File, state: FileDraft.State, numberOfBlocks: Int, isEmpty: Bool, uri: String, size: Int, mimeType: MimeType) {
        self.uploadID = uploadID
        self.file = file
        self.state = state
        self.numberOfBlocks = numberOfBlocks
        self.isEmpty = isEmpty
        self.uri = uri
        self.size = size
        self.mimeType = mimeType
    }

    public let isEmpty: Bool

    public static func == (lhs: FileDraft, rhs: FileDraft) -> Bool {
        lhs === rhs
    }
}

extension FileDraft {
    func assertIsCreatingFileDraft(in moc: NSManagedObjectContext) throws {
        try moc.performAndWait { guard file.in(moc: moc).isCreatingFileDraft() else { throw file.in(moc: moc).invalidState("The file is not in a creating file draft state.") } }
    }

    func assertIsUploadingRevision(in moc: NSManagedObjectContext) throws {
        try moc.performAndWait { guard file.in(moc: moc).isUploadingRevision() else { throw file.in(moc: moc).invalidState("The file is not in an uploading revision state.") } }
    }

    func assertIsCommitingRevision(in moc: NSManagedObjectContext) throws {
        try moc.performAndWait {
            guard file.in(moc: moc).isCommitingRevision() else {
                throw file.in(moc: moc).invalidState("The file is not in a commiting revision state.")
            }
        }
    }
}
