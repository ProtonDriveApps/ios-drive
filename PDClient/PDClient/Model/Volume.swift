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
        public let ID: String
        public let shareID: String
        public let linkID: String
    }
    
    public var ID: VolumeID
    public var maxSpace: Int?
    public var usedSpace: Int?
    public var state: State?
    public var share: Share
    public var restoreStatus: RestoreStatus?
}
