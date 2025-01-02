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

public enum FileProviderOperation: Int, Codable {
    /// Undefined is default value
    case undefined
    case create
    case modify
    case delete
    case fetchContents
    case fetchItem
    case enumerateItems
    case enumerateChanges
}

extension FileProviderOperation {

    public var name: String {
        switch self {
        case .undefined: "UNDEFINED"
        case .create: "CREATE"
        case .modify: "MODIFY"
        case .delete: "DELETE"
        case .fetchContents: "FETCHCONTENTS"
        case .fetchItem: "FETCHITEMS"
        case .enumerateItems: "ENUMERATEITEMS"
        case .enumerateChanges: "ENUMERATECHANGES"
        }
    }
}

extension URL: Identifiable {
    public var id: String {
        return self.absoluteString
    }
}
