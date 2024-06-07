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
import FileProvider

enum ItemConflictType {
    case nameClash
    case delete
    case edit

    var name: String {
        switch self {
        case .nameClash: return "Name Clash"
        case .edit: return "Edit conflict"
        case .delete: return "Delete conflict"
        }
    }

}

extension NSFileProviderItem {

    func conflictName(with type: ItemConflictType, at date: Date = Date()) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: date)

        if filename.fileExtension.isEmpty {
            let conflictName = "\(filename) (# \(type.name) \(dateString) \(String.randomAlphaNumeric(length: 7)) #)"
            return conflictName
        } else {
            let nameWithoutExtension = filename.nameExcludingExtension
            let fileExtension = filename.fileExtension()
            let conflictName = "\(nameWithoutExtension) (# \(type.name) \(dateString) \(String.randomAlphaNumeric(length: 7)) #).\(fileExtension)"
            return conflictName
        }
    }

}
