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

public extension DriveObservabilityIntegrityBeforeFebruary2025 {

    static func from(_ node: Node) -> Self {
        return from(node.createdDate)
    }

    static func from(_ share: Share) -> Self {
        guard let createTime = share.createTime else {
            return .unknown
        }

        return from(createTime)
    }

    private static var ddkReleaseDate: Date = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // A date is used to help segment uploads that occured before and after
        // a major client change. Initially, this was intended to distringuish
        // files uploaded (by any client) before all clients performed block upload
        // verification. In the case of macOS, we're most concerned with decryption
        // errors for files that could have been uploaded by the DDK (as there is no
        // upload attribution for files, we cannot use a release version to more
        // precisely categorize decryption failures). Hence we use the DDK beta
        // release date for this categorization.
        return dateFormatter.date(from: "2025-02-20")!
    }()

    static func from(_ date: Date) -> Self {
        return date < ddkReleaseDate ? .yes : .no
    }

}
