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

extension ItemActionsOutlet: ConflictResolution {

    public func findAndResolveConflictIfNeeded(
        tower: Tower,
        item: NSFileProviderItem,
        changeType: ItemActionChangeType,
        fields: NSFileProviderItemFields,
        contentsURL: URL?) async throws -> NSFileProviderItem?
    {
        #if os(iOS)
        return nil
        #else
        guard let (action, node) = identifyConflict(tower: tower, basedOn: item, changeType: changeType, fields: fields) else {
            ConsoleLogger.shared?.log("No conflict identified", osLogType: Self.self)
            return nil // no conflict found
        }
        
        ConsoleLogger.shared?.log("Conflict identified: \(action)", osLogType: Self.self)
        return try await tower.resolveConflict(between: item, with: contentsURL, and: node, applying: action)
        #endif
    }

}
