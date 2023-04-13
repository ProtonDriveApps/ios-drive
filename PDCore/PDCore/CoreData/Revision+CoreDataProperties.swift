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

extension Revision {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Revision> {
        return NSFetchRequest<Revision>(entityName: "Revision")
    }

    @NSManaged public var signatureAddress: String?
    @NSManaged public var created: Date?
    @NSManaged public var id: String
    @NSManaged public var manifestSignature: String?
    @NSManaged public var size: Int
    @NSManaged public var file: File
    @NSManaged public var blocks: Set<Block>
    @NSManaged public var thumbnail: Thumbnail?
    @NSManaged public var thumbnailHash: String?
    @NSManaged public var xAttributes: String?
}

// MARK: - Custom Upload properties
extension Revision {
    /// State of the Revision when it's being created and uploaded
    @NSManaged var uploadState: UploadState

    /// URL of the clear text resource before it's encrypted.
    @NSManaged var uploadableResourceURL: URL?

    /// Date in which the last request for uploading blocks has been performed
    @NSManaged var requestedUpload: Date?

    @objc enum UploadState: Int16, CustomStringConvertible {
        case none
        case created
        case encrypted
        case uploaded

        var description: String {
            switch self {
            case .none:
                return "None"
            case .created:
                return "Created"
            case .encrypted:
                return "Encrypted"
            case .uploaded:
                return "Uploaded"
            }
        }
    }
}

// MARK: Generated accessors for blocks
extension Revision {

    @objc(addBlocksObject:)
    @NSManaged public func addToBlocks(_ value: Block)

    @objc(removeBlocksObject:)
    @NSManaged public func removeFromBlocks(_ value: Block)

    @objc(addBlocks:)
    @NSManaged public func addToBlocks(_ values: Set<Block>)

    @objc(removeBlocks:)
    @NSManaged public func removeFromBlocks(_ values: Set<Block>)

}

public extension Revision {
    var identifier: RevisionIdentifier {
        RevisionIdentifier(share: file.shareID, file: file.id, revision: id)
    }
}
