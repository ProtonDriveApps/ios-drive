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
import PDClient

typealias SerializedEvent = PDClient.Event

public protocol GenericEventSerializer {
    func serialize(event: GenericEvent) throws -> Data
    func deserialize(data: Data) throws -> GenericEvent
}

enum EventSerializerError: Error {
    case invalidData
    case invalidEvent
}

public final class ClientEventSerializer: GenericEventSerializer {
    private lazy var encoder = JSONEncoder()
    private lazy var decoder = JSONDecoder()

    public init() {}

    public func serialize(event: GenericEvent) throws -> Data {
        guard let event = event as? PDClient.Event else {
            assert(false, "Wrong event type sent to \(#file)")
            Log.error("Serializing wrong type of GenericEvent", error: nil, domain: .events)
            throw EventSerializerError.invalidEvent
        }
        return try encoder.encode(event)
    }

    public func deserialize(data: Data) throws -> GenericEvent {
        do {
            return try decoder.decode(Event.self, from: data)
        } catch {
            if let event = try? decoder.decode(LegacyEvent.self, from: data) {
                return event.mapToEvent()
            } else {
                Log.error("Deserialization of event failed", error: error, domain: .events)
                throw EventSerializerError.invalidData
            }
        }
    }
}
