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

public protocol GenericEvent {
    var genericType: GenericEventType { get }
    var eventId: String { get }
    var shareId: String { get }
    var inLaneNodeId: String { get }
    var inLaneParentId: String? { get }
    var eventEmittedAt: TimeInterval { get }
}

public enum GenericEventType {
    case delete
    case updateMetadata
    case updateContent
    case create
}

public func ~= (lhs: [GenericEventType], rhs: GenericEventType) -> Bool {
    return lhs.contains(rhs)
}
