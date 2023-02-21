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
import ProtonCore_Networking

enum EventAPIRoutes {
    /// base route
    static let route: String = "/core/v4/events"

    /// default user route version
    static let v_user_default: Int = 4

    enum Router: Request {
        case getLatestEventID
        case getEvent(eventID: String, messageCounts: Bool, conversationCounts: Bool)

        var path: String {
            switch self {
            case .getLatestEventID:
                return route + "/latest"
            case let .getEvent(eventID, _, _):
                return route + "/\(eventID)"
            }
        }

        var isAuth: Bool {
            true
        }

        var header: [String: Any] {
            [:]
        }

        var apiVersion: Int {
            v_user_default
        }

        var method: HTTPMethod {
            .get
        }

        var parameters: [String: Any]? {
            switch self {
            case let .getEvent(_, messageCounts, conversationCounts):
                var ret: [String: Any] = [:]
                ret["MessageCounts"] = messageCounts
                ret["ConversationCounts"] = conversationCounts

                return ret
                
            case .getLatestEventID:
                return [:]
            }
        }
    }
}
