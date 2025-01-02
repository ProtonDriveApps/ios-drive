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

public struct LabelEvent: Codable {
    public let id: String
    public let action: Action
    public let label: Label?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case action, label
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.action = try container.decode(Action.self, forKey: .action)
        self.label = try container.decodeIfPresent(LabelEvent.Label.self, forKey: .label)
    }
}

extension LabelEvent {
    public struct Label: Codable {
        public let id: String
        public let name: String
        public let path: String
        public let type: LabelType
        /// Hex color, e.g. #c44800
        public let color: String
        public let order: Int
        
        enum CodingKeys: String, CodingKey {
            case id = "ID"
            case name, path, type, color, order
        }
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<LabelEvent.Label.CodingKeys> = try decoder.container(keyedBy: LabelEvent.Label.CodingKeys.self)
            self.id = try container.decode(String.self, forKey: LabelEvent.Label.CodingKeys.id)
            self.name = try container.decode(String.self, forKey: LabelEvent.Label.CodingKeys.name)
            self.path = try container.decode(String.self, forKey: LabelEvent.Label.CodingKeys.path)
            self.type = try container.decode(LabelEvent.LabelType.self, forKey: LabelEvent.Label.CodingKeys.type)
            self.color = try container.decode(String.self, forKey: LabelEvent.Label.CodingKeys.color)
            self.order = try container.decode(Int.self, forKey: LabelEvent.Label.CodingKeys.order)
        }
        
        public init(
            id: String,
            name: String,
            path: String,
            type: LabelType,
            color: String,
            order: Int
        ) {
            self.id = id
            self.name = name
            self.path = path
            self.type = type
            self.color = color
            self.order = order
        }
    }
    
    public enum LabelType: Int, Codable {
        case messageLabel = 1
        case contact
        case messageFolder
    }
}
