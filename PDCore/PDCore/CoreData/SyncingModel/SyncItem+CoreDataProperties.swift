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

import CoreData

extension SyncItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncItem> {
        return NSFetchRequest<SyncItem>(entityName: "SyncItem")
    }

    @NSManaged public var id: String
    @NSManaged public var errorRetryCount: Int64
    @NSManaged public var fileSize: NSNumber?
    @NSManaged public var modificationTime: Date

    @NSManaged public var progress: Int
    /// Automatically set in the didSet of "state"
    @NSManaged public var inProgress: Bool

    /// Order in which states are shown in the tray app.
    /// Automatically set in the didSet of "state".
    @NSManaged public var sortOrder: Int64

    /// FileProvider related
    @NSManaged public var filename: String?
    @NSManaged public var mimeType: String?
    @NSManaged public var location: String?
    @NSManaged public var errorDescription: String?

}
