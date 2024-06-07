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
//

import Foundation
import CoreData

extension PersistedEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PersistedEvent> {
        return NSFetchRequest<PersistedEvent>(entityName: "PersistedEvent")
    }

    @NSManaged public var contents: Data?
    @NSManaged public var eventEmittedAt: Double
    @NSManaged public var eventId: String?
    @NSManaged public var isProcessed: Bool
    @NSManaged public var isEnumerated: Bool
    @NSManaged public var providerType: String?
    @NSManaged public var shareId: String?

}
