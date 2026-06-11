// Copyright (c) 2026 Proton AG
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

public enum UILoggableEvent: JSONLoggable {
    case uiUpdate([String])
    case userAction([String: AnyEncodable])

    public var eventName: String {
        switch self {
        case .uiUpdate: return "uiUpdate"
        case .userAction: return "userAction"
        }
    }

    public var domain: LogDomain { .ui }

    public var logLevel: LogLevel { .trace }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        let data: Encodable = switch self {
        case .uiUpdate(let context): ["params": AnyEncodable(context)]
        case .userAction(let params): ["params": AnyEncodable(params)]
        }

        try container.encode(data)
    }
}
