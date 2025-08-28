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

extension Volume {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Volume> {
        return NSFetchRequest<Volume>(entityName: "Volume")
    }

    @NSManaged public var id: String
    @NSManaged public var maxSpace: Int
    @NSManaged public var usedSpace: Int
    @NSManaged public var shares: Set<Share>
    // Cannot be nil, so by default the value will be `undetermined`.
    // On iOS, this should be populated correctly, since we perform migration of type when launching app.
    // Don't use on macOS unless migration is also added.
    @NSManaged public var type: VolumeType

    @objc public enum VolumeType: Int16, CustomStringConvertible {
        case undetermined
        case main
        case photo

        public var description: String {
            switch self {
            case .undetermined:
                return "undetermined"
            case .main:
                return "main"
            case .photo:
                return "photo"
            }
        }
    }
}
