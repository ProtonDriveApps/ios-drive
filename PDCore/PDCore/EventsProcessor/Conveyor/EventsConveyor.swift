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

import CoreData

public typealias EventPack = (event: GenericEvent, share: String, objectID: NSManagedObjectID)

public protocol EventsConveyor: AnyObject {
    func prepareForProcessing()
    func next() -> EventPack?
    func disregard(_ id: NSManagedObjectID)
    func completeProcessing(of id: NSManagedObjectID)
    func clearUp()
    func record(_ events: [GenericEvent])
    func hasUnprocessedEvents() -> Bool

    func lastFullyHandledEvent() -> GenericEvent?
    func lastEventAwaitingEnumeration() -> GenericEvent?
    func lastReceivedEvent() -> GenericEvent?
    func history(since anchor: EventID?) throws -> [EventPack]
    func setEnumerated(_ objectIDs: [NSManagedObjectID])

    var latestEventFetchTime: Date? { get set }
    var latestFetchedEventID: EventID? { get set }
    var referenceDate: Date? { get set }
    var referenceID: EventID? { get set }
}
