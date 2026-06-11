// Copyright (c) 2026 Proton AG
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
import ProtonDriveSDK

public struct PhotoAttributes {
    /// Extended attributes
    public let additionalMetadata: [AdditionalMetadata]
    public let captureTime: Date
    public let childrenCount: Int
    /// Photo asset cloud identifier
    public let cloudIdentifier: String
    public let fileSize: Int64
    /// File path
    public let fileURL: URL
    /// Temporary identifier, id is a UUID
    public let identifier: AnyVolumeIdentifier
    /// nil when this is main photo
    public let mainPhotoUid: SDKNodeUid?
    public let mediaType: String
    public let modificationDate: Date
    /// photo name with file extension
    public let name: String
    /// Photo root folder identifier
    public let parentFolderIdentifier: SDKNodeUid
    /// Photo tags
    public let tags: [Int]
    public let uploadID: UUID

    public init(
        additionalMetadata: [AdditionalMetadata],
        captureTime: Date,
        childrenCount: Int,
        cloudIdentifier: String,
        fileSize: Int64,
        fileURL: URL,
        identifier: AnyVolumeIdentifier,
        mainPhotoUid: SDKNodeUid?,
        mediaType: String,
        modificationDate: Date,
        name: String,
        parentFolderIdentifier: SDKNodeUid,
        tags: [Int],
        uploadID: UUID
    ) {
        self.additionalMetadata = additionalMetadata
        self.captureTime = captureTime
        self.childrenCount = childrenCount
        self.cloudIdentifier = cloudIdentifier
        self.fileSize = fileSize
        self.fileURL = fileURL
        self.identifier = identifier
        self.mainPhotoUid = mainPhotoUid
        self.mediaType = mediaType
        self.modificationDate = modificationDate
        self.name = name
        self.parentFolderIdentifier = parentFolderIdentifier
        self.tags = tags
        self.uploadID = uploadID
    }
}
