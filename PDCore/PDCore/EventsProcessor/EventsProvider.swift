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
import CoreData
import PDClient

public typealias EventID = PDClient.EventID
public typealias ScanEventsHandler = (Result<ScanEventsResult, Error>) -> Void

public struct ScanEventsResult {
    public var latestEventID: EventID
    public var events: [GenericEvent]
    public var more: MoreEvents
}

public protocol EventsListener: AnyObject {
    func processorReceivedEvents()
    func processorAppliedEvents(affecting: [NodeIdentifier])
}

protocol EventsProvider: AnyObject {
    var lastScannedEventID: String? { get }
    func convert(_ inLaneNodeID: String?, storage: StorageManager, moc: NSManagedObjectContext) -> String?
    func scanEventsFromRemote(of shareID: String, handler: @escaping ScanEventsHandler)
    func update(shareId: String, from event: GenericEvent, storage: StorageManager, moc: NSManagedObjectContext) -> [NodeIdentifier]
    func ignored(event: GenericEvent, storage: StorageManager, moc: NSManagedObjectContext)
    
    func clearUp()
    func moveLastScannedEventID(after eventsPack: ScanEventsResult)
    
    static func pack(_ genericEvent: GenericEvent) -> Data?
    static func unpack(_ package: Data) -> GenericEvent?
}

extension EventsProvider {
    func findNode(id: String?, by attribute: String = "id", storage: StorageManager, moc: NSManagedObjectContext) -> Node? {
        guard let id = id else { return nil }
        let asFile: File? = storage.existing(with: [id], by: attribute, in: moc).first
        let asFolder: Folder? = storage.existing(with: [id], by: attribute, in: moc).first
        return asFolder ?? asFile
    }
    
    func recordEventsIntoConveyor(pack: ScanEventsResult, for shareID: String, to persistentQueue: EventStorageManager) {
        let events = pack.events
        persistentQueue.persist(events: zip(events, events.compactMap(Self.pack)),
                                provider: String(describing: Self.self),
                                     shareId: shareID)
        self.moveLastScannedEventID(after: pack)
    }
}
