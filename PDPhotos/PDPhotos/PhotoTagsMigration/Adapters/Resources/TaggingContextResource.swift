// Copyright (c) 2025 Proton AG
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
import PDCore

protocol TaggingContextResource {
    func getTaggingContext(for identifier: AnyVolumeIdentifier) async -> MigrationAnalyzeResult
}

final class CoreDataTaggingContextResource: TaggingContextResource {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func getTaggingContext(for identifier: AnyVolumeIdentifier) async -> MigrationAnalyzeResult {
        let (photo, tag): (CoreDataPhoto?, [Int]) = await context.perform { [context] in
            guard let photo = CoreDataPhoto.fetch(identifier: identifier, in: context) else { return (nil, []) }
            let tag = photo.tags ?? []
            return (photo, tag)
        }
        guard photo != nil else {
            Log.error("Tagging aborted for \(identifier)", error: nil, domain: .photosTagMigration)
            return MigrationAnalyzeResult(
                taggingContext: TaggingContext(assignedTags: [], control: .abort),
                xAttrContext: XAttrBackfillContext(extendedAttributes: nil, control: .abort)
            )
        }

        let existingTagInts = tag.compactMap { Int($0) }
        let existingTags = Set(existingTagInts.compactMap(PhotoTag.init(rawValue:)))

        // Define tags that are allowed to be present without skipping
        let autoDetectedOrAllowed: Set<PhotoTag> = PhotoTag.autoDetectedSystemTags.union([PhotoTag.favorites])

        // If any tag is *not* in the allowed set, consider the photo fully tagged during the upload process
        if !existingTags.isSubset(of: autoDetectedOrAllowed) {
            return MigrationAnalyzeResult(
                taggingContext: TaggingContext(assignedTags: existingTags, control: .taggedOnUpload),
                xAttrContext: XAttrBackfillContext(extendedAttributes: nil, control: .continue)
            )
        }

        return MigrationAnalyzeResult(
            taggingContext: TaggingContext(assignedTags: existingTags, control: .continue),
            xAttrContext: XAttrBackfillContext(extendedAttributes: nil, control: .continue)
        )
    }

}
