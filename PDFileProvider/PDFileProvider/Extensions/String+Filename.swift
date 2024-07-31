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
import PDCore

extension String {

    var nameExcludingExtension: String {
        URL(fileURLWithPath: self).deletingPathExtension().lastPathComponent
    }

    var fileExtension: String {
        URL(fileURLWithPath: self).pathExtension
    }

    func appendingExtension(_ pathExtension: String) -> String {
        URL(fileURLWithPath: self).appendingPathExtension(pathExtension).lastPathComponent
    }

    func filenameNormalizedForFilesystem(basedOn mimeType: String) -> String {
        switch mimeType {
        case ProtonDocumentConstants.mimeType:
            return self.appendingExtension(ProtonDocumentConstants.fileExtension)
        default:
            return self
        }
    }

    /// Removes the .protondoc file extension from files before pushing changes to remote
    func filenameNormalizedForRemote() -> String {
        switch self.fileExtension {
        case ProtonDocumentConstants.fileExtension:
            return self.nameExcludingExtension
        default:
            return self
        }
    }
}
