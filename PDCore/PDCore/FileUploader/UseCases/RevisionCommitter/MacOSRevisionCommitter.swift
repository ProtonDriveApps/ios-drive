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

import CoreData
import Foundation

final class MacOSRevisionCommitter: NewFileRevisionCommitter {

    override func finalizeRevision(in file: File, commitableRevision: CommitableRevision, completion: @escaping Completion) {
        super.finalizeRevision(in: file, commitableRevision: commitableRevision, completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                // For macOS we want to get rid of the encrypted blocks after the upload to free storage
                file.activeRevision?.removeOldBlocks(in: self.moc)
                try? self.moc.saveOrRollback()
                completion(result)
            case .failure:
                completion(result)
            }
        })
    }
}
