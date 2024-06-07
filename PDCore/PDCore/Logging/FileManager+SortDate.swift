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

extension FileManager {

    public func fileCreationDateSort(lhs: URL, rhs: URL) -> Bool {
        creationDate(of: lhs)?.timeIntervalSince1970 ?? 0 < creationDate(of: rhs)?.timeIntervalSince1970 ?? 0
    }

    public func creationDate(of url: URL) -> Date? {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try attributesOfItem(atPath: url.path)
        } catch let error {
            Log.error("Failed to get attributes of file at \(url .path) with error \(error)", domain: .fileManager)
            return nil
        }

        guard let date = attributes[.creationDate] as? Date else {
            Log.error("Failed to get attributes of file at \(url .path)", domain: .fileManager)
            return nil
        }
        return date
    }

}
