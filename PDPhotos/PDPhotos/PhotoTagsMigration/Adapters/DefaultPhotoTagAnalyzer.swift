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
import PDCore

final class DefaultPhotoTagAnalyzer: PhotoTagAnalyzer {
    private let initialTaggingContextResource: TaggingContextResource
    private let driveMetaPhotoTagRule: PhotoTagRule
    private let photosMetaPhotoTagRule: PhotoTagRule
    private let fileExifPhotoTagRule: PhotoTagRule

    init(
        initialTaggingContextResource: TaggingContextResource,
        driveMetaPhotoTagRule: PhotoTagRule,
        photosMetaPhotoTagRule: PhotoTagRule,
        fileExifPhotoTagRule: PhotoTagRule
    ) {
        self.initialTaggingContextResource = initialTaggingContextResource
        self.driveMetaPhotoTagRule = driveMetaPhotoTagRule
        self.photosMetaPhotoTagRule = photosMetaPhotoTagRule
        self.fileExifPhotoTagRule = fileExifPhotoTagRule
    }

    func analyze(identifiers: [AnyVolumeIdentifier]) async throws -> [MigrationAnalyzeReport] {
        Log.info("Starting photo tag analysis for \(identifiers.count) identifiers.", domain: .photosTagMigration)
        var result: [MigrationAnalyzeReport] = []

        do {
            for identifier in identifiers {
                try Task.checkCancellation()
                
                Log.debug("Analyzing identifier: \(identifier.id)", domain: .photosTagMigration)
                // Possible state
                // taggingContext: abort, taggedOnUpload, continue
                // xAttrContext: abort, continue
                var analyzeResult = await initialTaggingContextResource.getTaggingContext(for: identifier)
                Log.debug(
                    "Will start analysis for \(identifier.id) with initial tags: \(analyzeResult.taggingContext.assignedTags)",
                    domain: .photosTagMigration
                )

                // We could not find the object in CoreData, it was probably deleted
                if analyzeResult.bothAborted {
                    Log.warning("Skipping identifier \(identifier.id): Initial context aborted, item may have been deleted.", domain: .photosTagMigration)
                    continue
                }
                
                try Task.checkCancellation()
                
                // Apply Drive Meta Rule
                Log.debug("Applying driveMetaPhotoTagRule to \(identifier.id)", domain: .photosTagMigration)
                // Possible state
                // taggingContext: abort, taggedOnUpload, continue
                // xAttrContext: (inherit) abort, continue
                analyzeResult = try await driveMetaPhotoTagRule.apply(toPhoto: identifier, analyzeResult: analyzeResult)

                if analyzeResult.bothAborted {
                    Log.warning("Skipping identifier \(identifier.id): Aborted after driveMetaPhotoTagRule.", domain: .photosTagMigration)
                    continue
                }
                
                try Task.checkCancellation()
                
                // Apply Photos Meta Rule
                Log.debug("Applying photosMetaPhotoTagRule to \(identifier.id)", domain: .photosTagMigration)
                // Possible state
                // taggingContext: abort, taggedOnUpload continue, finished
                // xAttrContext: abort, upToDate, finished
                analyzeResult = try await photosMetaPhotoTagRule.apply(toPhoto: identifier, analyzeResult: analyzeResult)

                if analyzeResult.bothAborted {
                    Log.warning("Skipping identifier \(identifier.id): Aborted after photosMetaPhotoTagRule.", domain: .photosTagMigration)
                    continue
                }

                if analyzeResult.isLocalAnalysisDone {
                    if analyzeResult.isRemoteUpToDate {
                        Log.debug("Skipping identifier \(identifier.id): Tags and xattr already correct on upload.", domain: .photosTagMigration)
                    } else {
                        append(result: &result, analyzeResult: analyzeResult, identifier: identifier)
                    }
                    continue
                }

                try Task.checkCancellation()
                
                // Apply File EXIF Rule
                Log.debug("Applying fileExifPhotoTagRule to \(identifier.id)", domain: .photosTagMigration)
                analyzeResult = try await fileExifPhotoTagRule.apply(toPhoto: identifier, analyzeResult: analyzeResult)
                append(result: &result, analyzeResult: analyzeResult, identifier: identifier)
            }
            
            Log.info("Photo tag analysis complete. Found tags for \(result.count) of \(identifiers.count) photos.", domain: .photosTagMigration)
            return result
        } catch let error as CancellationError {
            Log.info("Photo tag analysis has been cancelled.", domain: .photosTagMigration)
            throw error
        } catch {
            Log.warning("Photo tag analysis failed.", domain: .photosTagMigration)
            throw error
        }
    }

    private func append(
        result: inout [MigrationAnalyzeReport],
        analyzeResult: MigrationAnalyzeResult,
        identifier: AnyVolumeIdentifier
    ) {
        let canUpdateTag = analyzeResult.taggingContext.control != .taggedOnUpload
        let assignedTags = analyzeResult.taggingContext.assignedTags
        let canUpdateXAttr = analyzeResult.xAttrContext.control == .finished
        let extendedAttributes = analyzeResult.xAttrContext.extendedAttributes
        let report = MigrationAnalyzeReport(
            identifier: identifier,
            updatedTags: canUpdateTag ? Array(assignedTags) : [],
            extendedAttributes: canUpdateXAttr ? analyzeResult.xAttrContext.extendedAttributes : nil
        )
        result.append(report)
        Log.debug("Finished analysis for \(identifier.id). canUpdateTag: \(canUpdateTag), tags: \(assignedTags), canUpdateXAttr: \(canUpdateXAttr), XAttr non-nil: \(extendedAttributes != nil)", domain: .photosTagMigration)
    }
}
