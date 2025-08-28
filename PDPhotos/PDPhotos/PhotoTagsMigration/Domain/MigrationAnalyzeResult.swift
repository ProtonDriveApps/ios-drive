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

public struct MigrationAnalyzeResult {
    var taggingContext: TaggingContext
    var xAttrContext: XAttrBackfillContext

    var bothAborted: Bool {
        taggingContext.control == .abort && xAttrContext.control == .abort
    }

    var isLocalAnalysisDone: Bool {
        (taggingContext.control == .finished || taggingContext.control == .taggedOnUpload) &&
        (xAttrContext.control == .finished || xAttrContext.control == .upToDate)
    }

    var isRemoteUpToDate: Bool {
        taggingContext.control == .taggedOnUpload && xAttrContext.control == .upToDate
    }

    func update(taggingContext: TaggingContext) -> MigrationAnalyzeResult {
        return MigrationAnalyzeResult(taggingContext: taggingContext, xAttrContext: xAttrContext)
    }

    func update(xAttrContext: XAttrBackfillContext) -> MigrationAnalyzeResult {
        return MigrationAnalyzeResult(taggingContext: taggingContext, xAttrContext: xAttrContext)
    }
}
