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

public struct TelemetryEventInfo {
    let measurementGroup: String
    let event: String
    let values: [String: Double]
    let dimensions: [String: String]

    public init(measurementGroup: String, event: String, values: [String: Double], dimensions: [String: String]) {
        self.measurementGroup = measurementGroup
        self.event = event
        self.values = values
        self.dimensions = dimensions
    }
}

struct TelemetryResponse: Codable {
    let code: Int
}

/// Send a list of events to the data telemetry system
/// POST: [domain]/api/data/v1/stats/multiple
struct TelemetryEndpoint: Endpoint {
    typealias Response = TelemetryResponse

    private struct Body: Encodable {
        struct Event: Encodable {
            let MeasurementGroup: String
            let Event: String
            let Values: [String: Double]
            let Dimensions: [String: String]
        }

        let EventInfo: [Event]
    }

    var request: URLRequest

    init(events: [TelemetryEventInfo], service: APIService, credential: ClientCredential) throws {
        // url
        var components = service.baseComponents
        components.path = "/data/v1/stats/multiple"
        let url = try components.asURL()

        // request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // headers
        var headers = service.baseHeaders
        headers.merge(service.authHeaders(credential), uniquingKeysWith: { $1 })
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // body
        let events = events.map { info in
            Body.Event(MeasurementGroup: info.measurementGroup, Event: info.event, Values: info.values, Dimensions: info.dimensions)
        }
        let body = Body(EventInfo: events)
        request.httpBody = try? JSONEncoder().encode(body)

        self.request = request
    }
}
