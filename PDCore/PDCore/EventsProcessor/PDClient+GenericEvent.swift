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
import PDClient

extension PDClient.Event: GenericEvent {
    public var genericType: GenericEventType {
        switch self.eventType {
        case .create: return .create
        case .delete: return .delete
        case .updateContent: return .updateContent
        case .updateMetadata: return .updateMetadata
        }
    }
    public var eventEmittedAt: TimeInterval {
        self.createTime
    }
    public var shareId: String {
        self.contextShareID
    }
    public var eventId: String {
        self.eventID
    }
    public var inLaneNodeId: String {
        self.link.linkID
    }
    public var inLaneParentId: String? {
        self.link.parentLinkID
    }
    public var volumeId: String {
        link.volumeID
    }
}
