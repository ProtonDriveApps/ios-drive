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

public struct DriveUserSettings: Equatable {
    public let layout: LayoutPreference
    public let sort: SortPreference
    public let revisionRetentionDays: Int
    public let b2bPhotosEnabled: Bool
    public let docsCommentsNotificationsEnabled: Bool
    public let docsCommentsNotificationsIncludeDocumentName: Bool
    public let photoTags: [Int]

    public init(layout: LayoutPreference, sort: SortPreference, revisionRetentionDays: Int, b2bPhotosEnabled: Bool, docsCommentsNotificationsEnabled: Bool, docsCommentsNotificationsIncludeDocumentName: Bool, photoTags: [Int]) {
        self.layout = layout
        self.sort = sort
        self.revisionRetentionDays = revisionRetentionDays
        self.b2bPhotosEnabled = b2bPhotosEnabled
        self.docsCommentsNotificationsEnabled = docsCommentsNotificationsEnabled
        self.docsCommentsNotificationsIncludeDocumentName = docsCommentsNotificationsIncludeDocumentName
        self.photoTags = photoTags
    }

    public static let `default` = DriveUserSettings(
        layout: .list,
        sort: .modifiedDescending,
        revisionRetentionDays: 180,
        b2bPhotosEnabled: false,
        docsCommentsNotificationsEnabled: false,
        docsCommentsNotificationsIncludeDocumentName: false,
        photoTags: [0, 2, 3, 7, 9]
    )
}
