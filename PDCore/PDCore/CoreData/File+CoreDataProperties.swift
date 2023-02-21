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

extension File {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<File> {
        return NSFetchRequest<File>(entityName: "File")
    }

    @NSManaged public var contentKeyPacket: String?
    @NSManaged public var contentKeyPacketSignature: String?
    @NSManaged public var revisions: Set<Revision>
    @NSManaged public var activeRevision: Revision? // this will be nil until we'll request full metadata of the file
}

// MARK: - Custom properties
extension File {
    public var uploadIDURL: URL? {
        get { URL(fileURLWithPath: self.uploadIdRaw ?? "") }
        set { self.uploadIdRaw = newValue?.path }
    }
    @NSManaged private var uploadIdRaw: String? // should be removed by finish handler of Upload operation

    @NSManaged public var uploadID: UUID? // should be removed by finish handler of Upload operation
    @NSManaged public var activeRevisionDraft: Revision?
}

// MARK: Generated accessors for revisions
extension File {

    @objc(addRevisionsObject:)
    @NSManaged public func addToRevisions(_ value: Revision)

    @objc(removeRevisionsObject:)
    @NSManaged public func removeFromRevisions(_ value: Revision)

    @objc(addRevisions:)
    @NSManaged public func addToRevisions(_ values: Set<Revision>)

    @objc(removeRevisions:)
    @NSManaged public func removeFromRevisions(_ values: Set<Revision>)

}

extension File {
    var supportsThumbnail: Bool {
        return MimeType(value: mimeType).isImage
    }
}
