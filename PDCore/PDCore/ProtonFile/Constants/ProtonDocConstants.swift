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

public struct ProtonDocConstants {
    public static let fileExtension = "protondoc"
    public static let uti = "me.proton.drive.doc"
    public static let mimeType = "application/vnd.proton.doc"
}

public struct ProtonSheetConstants {
    public static let fileExtension = "protonsheet"
    public static let uti = "me.proton.drive.sheet"
    public static let mimeType = "application/vnd.proton.sheet"
}

public enum ProtonFileType: Equatable {
    case doc
    case sheet

    public init?(uti: String) {
        switch uti {
        case ProtonDocConstants.uti:
            self = .doc
        case ProtonSheetConstants.uti:
            self = .sheet
        default:
            return nil
        }
    }
}
