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

public struct ReportableSyncItem: Encodable {

    public let id: String
    public let modificationTime: Date
    public let objectIdentifier: String
    public let filename: String
    public let location: String?
    public let mimeType: String?
    public let fileSize: Int?
    public let fileProviderOperation: FileProviderOperation
    public let state: SyncItemState
    public let progress: Int
    public var errorDescription: String?

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
        self.progress = item.progress
        self.errorDescription = item.errorDescription?.split(separator: "\n").first?.description
    }

    // this is the initializer for the file provider side
    public init(id: String,
                modificationTime: Date,
                filename: String?,
                location: String?,
                mimeType: String?,
                fileSize: Int?,
                operation: FileProviderOperation,
                state: SyncItemState,
                progress: Int,
                errorDescription: String? = nil) {
        self.id = id
        self.modificationTime = modificationTime
        self.objectIdentifier = ""
        self.filename = filename ?? ""
        self.location = location
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.fileProviderOperation = operation
        self.state = state
        self.progress = progress
        self.errorDescription = errorDescription
    }

    public var isFolder: Bool {
        mimeType == Folder.mimeType
    }
}

extension ReportableSyncItem: Identifiable, Hashable, Equatable {
    public static func == (lhs: ReportableSyncItem, rhs: ReportableSyncItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.modificationTime == rhs.modificationTime &&
        lhs.objectIdentifier == rhs.objectIdentifier &&
        lhs.filename == rhs.filename &&
        lhs.location == rhs.location &&
        lhs.mimeType == rhs.mimeType &&
        lhs.fileSize == rhs.fileSize &&
        lhs.fileProviderOperation == rhs.fileProviderOperation &&
        lhs.state == rhs.state &&
        lhs.progress == rhs.progress &&
        lhs.errorDescription == rhs.errorDescription
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(modificationTime)
        hasher.combine(objectIdentifier)
        hasher.combine(filename)
        hasher.combine(location)
        hasher.combine(mimeType)
        hasher.combine(fileSize)
        hasher.combine(fileProviderOperation)
        hasher.combine(state)
        hasher.combine(progress)
        hasher.combine(errorDescription)
    }
}

extension ReportableSyncItem: CustomDebugStringConvertible {
    public var debugDescription: String {
        "fileName: \(String(describing: filename))\n" +
        "location: \(String(describing: location))\n" +
        "mimeType: \(String(describing: mimeType))\n" +
        "fileSize: \(String(describing: fileSize))\n" +
        "modificationTime: \(modificationTime)\n" +
        "operation: \(fileProviderOperation)\n" +
        "state: \(state)\n" +
        "progress: \(progress.description)\n" +
        "error: \(errorDescription ?? "n/a")\n"
    }
}
