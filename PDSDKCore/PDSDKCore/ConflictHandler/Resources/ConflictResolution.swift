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

/// Defines the preferred resolution when a file upload conflict occurs
public enum ConflictResolution {
    /// Uploads the file as a new one by appending a suffix to the filename
    case newFile
    /// Uploads the file as a new revision
    case newRevision
    /// Throws an error so the client can display it to the user or let the user choose a preferred resolution
    case undetermined
}
