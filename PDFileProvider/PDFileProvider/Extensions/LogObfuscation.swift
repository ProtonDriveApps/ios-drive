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

import FileProvider
import PDCore

public extension Node {
    static prefix func ~ (_ node: Node) -> String {
        #if DEBUG
        return node.decryptedName
        #else
        return node.id ?? "UNKNOWN"
        #endif
    }
}

extension NSFileProviderItem {
    public static prefix func ~ (_ item: Self) -> String {
        #if DEBUG
        return item.filename
        #else
        return item.itemIdentifier.rawValue
        #endif
    }
}

extension NSFileProviderItemIdentifier: Swift.CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .rootContainer: return "ROOT"
        case .trashContainer: return "TRASH"
        case .workingSet: return "WORKING_SET"
        default:
            #if DEBUG
            return rawValue
            #else
            return Emojifier.emoji.symbolicate(self.rawValue)
            #endif
        }
    }
}
