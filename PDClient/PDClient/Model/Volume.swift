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

public typealias PermissionMask = Int // should be something smarter, like OptionSet
public typealias AttriburesMask = Int

public struct Volume: Codable {
    public typealias VolumeID = String

    public enum RestoreStatus: Int, Codable {
        case failed = -1
        case done = 0
        case inProgress = 1
    }

    public enum State: Int, Codable {
        case active = 1
        case deleted = 2
        case locked = 3
        case restored = 4
    }

    public struct Share: Codable {
        public let shareID: String
        public let linkID: String
        
        public init(shareID: String, linkID: String) {
            self.shareID = shareID
            self.linkID = linkID
        }
    }

    public enum VolumeType: Int, Codable {
        case main = 1
        case photo = 2
    }

    public var volumeID: VolumeID
    public var createTime: TimeInterval?
    public var modifyTime: TimeInterval?
    public var uploadedBytes: Int
    public var maxSpace: Int?
    public var usedSpace: Int?
    public var state: State?
    public var share: Share
    public var restoreStatus: RestoreStatus?
    public let type: VolumeType

    public init(volumeID: VolumeID, createTime: TimeInterval? = nil, modifyTime: TimeInterval? = nil,
                uploadedBytes: Int, maxSpace: Int? = nil, usedSpace: Int? = nil, state: State? = nil,
                share: Share, restoreStatus: RestoreStatus? = nil, type: VolumeType = .main) {
        self.volumeID = volumeID
        self.createTime = createTime
        self.modifyTime = modifyTime
        self.uploadedBytes = uploadedBytes
        self.maxSpace = maxSpace
        self.usedSpace = usedSpace
        self.state = state
        self.share = share
        self.restoreStatus = restoreStatus
        self.type = type
    }
}
