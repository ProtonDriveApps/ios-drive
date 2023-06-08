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

import CoreData

@objc(Photo)
public class Photo: File {
    @NSManaged public var timestamp: Date

    @NSManaged public var parent: Photo?
    @NSManaged public var children: Set<Photo>

    @NSManaged public var photoRevision: PhotoRevision

    // Deprecated
    @available(*, deprecated, message: "Not needed")
    @NSManaged override public var revisions: Set<Revision>

    @available(*, deprecated, message: "Not needed")
    @NSManaged override public var activeRevision: Revision?

    // Transient
    @objc public var monthIdentifier: String? {
        willAccessValue(forKey: "monthIdentifier")
        var cachedIdentifier = primitiveValue(forKey: "monthIdentifier") as? String
        didAccessValue(forKey: "monthIdentifier")

        if cachedIdentifier == nil {
            let calendar = Photo.calendar
            let components = calendar.dateComponents([.year, .month], from: timestamp)
            let year = components.year ?? 0
            let month = components.month ?? 0
            cachedIdentifier = "\(year) \(month)"
            setPrimitiveValue(cachedIdentifier, forKey: "monthIdentifier")
        }
        return cachedIdentifier
    }
    private static let calendar = Calendar.current
}
