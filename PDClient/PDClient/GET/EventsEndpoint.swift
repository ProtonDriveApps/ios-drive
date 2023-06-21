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

public enum EventType: Int, Codable {
    case delete = 0
    case create = 1
    case updateContent = 2
    case updateMetadata = 3    
}

public struct Event: Encodable {
    public var contextShareID: Share.ShareID
    public var eventID: EventID
    public var eventType: EventType
    public var createTime: TimeInterval
    public var link: Link
    
    enum CodingKeys: String, CodingKey {
        case eventID
        case eventType
        case createTime
        case link
        case contextShareID
    }
    
    private struct MinimalLink: Codable {
        public var linkID: String
    }
}

extension Event: Decodable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.eventID = try values.decode(EventID.self, forKey: .eventID)
        self.eventType = try values.decode(EventType.self, forKey: .eventType)
        self.createTime = try values.decode(TimeInterval.self, forKey: .createTime)
        
        // contextShareID is allowed to be missing in .delete events, but others should have it
        do {
            self.contextShareID = try values.decode(Share.ShareID.self, forKey: .contextShareID)
        } catch where eventType == .delete {
            self.contextShareID = ""
        }

        do {
            // .update and .create events come with a full link inside
            self.link = try values.decode(Link.self, forKey: .link)
        } catch _ where self.eventType == .delete {
            // delete events come with only LinkID inside
            let linkID = try values.decode(MinimalLink.self, forKey: .link).linkID
            
            // so we create an empty Link object to obscure this fact from higher layers of the app
            self.link = Link.emptyDeletedLink(id: linkID)
        } catch let error {
            // if that did not help as well - throw encoding error
            assert(false, error.localizedDescription)
            throw error
        }
    }
}

public struct EventsEndpoint: Endpoint {
    public typealias Response = EventsResponse

    public var request: URLRequest
    
    public init(volumeID: Volume.VolumeID, since lastKnown: EventID, service: APIService, credential: ClientCredential) {
        // url
        var url = service.url(of: "/volumes")
        url.appendPathComponent(volumeID)
        url.appendPathComponent("/events")
        url.appendPathComponent(lastKnown)
        
        // request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        self.request = request
    }
}

public struct EventsResponse: Codable {
    public let code: Int
    public let events: [Event]
    public let eventID: String
    public let more: More
    public let refresh: Refresh

    public init(code: Int, events: [Event], eventID: String, more: More, refresh: Refresh) {
        self.code = code
        self.events = events
        self.eventID = eventID
        self.more = more
        self.refresh = refresh
    }

    public enum More: Int, Codable {
        case `false` = 0
        case `true` = 1
    }

    public enum Refresh: Int, Codable {
        case `false` = 0
        case `true` = 1
    }
}
