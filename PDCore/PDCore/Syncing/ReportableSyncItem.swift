// Copyright (c) 2024 Proton AG
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

public struct ReportableSyncItem: Identifiable, Hashable, Equatable {

    public let id: String
    public let modificationTime: Date
    public let objectIdentifier: String
    public let filename: String
    public let location: String?
    public let mimeType: String?
    public let fileSize: Int?
    public let fileProviderOperation: FileProviderOperation
    public let state: SyncItemState
    public var description: String?

    // this is the initializer for the app side
    public init(item: SyncItem) {
        self.id = item.id
        self.modificationTime = item.modificationTime
        self.objectIdentifier = item.objectIdentifier
        self.filename = item.filename ?? ""
        self.location = item.location
        self.mimeType = item.mimeType
        self.fileSize = item.fileSize?.intValue
        self.fileProviderOperation = item.fileProviderOperation
        self.state = item.state
        self.description = item.errorDescription
    }

    // this is the initializer for the file provider side
    public init(id: String, modificationTime: Date, filename: String?, location: String?, mimeType: String?, fileSize: Int?, operation: FileProviderOperation, state: SyncItemState, description: String? = nil) {
        self.id = id
        self.modificationTime = modificationTime
        self.objectIdentifier = ""
        self.filename = filename ?? ""
        self.location = location
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.fileProviderOperation = operation
        self.state = state
        self.description = description
    }
}

public extension ReportableSyncItem {

    var isFolder: Bool {
        mimeType == Folder.mimeType
    }
}
