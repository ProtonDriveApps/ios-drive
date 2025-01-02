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

import ProtonCoreUIFoundations
import SwiftUI

public protocol SectionItemDisplayable {
    var identifier: String { get }
    var text: String { get }
    var icon: Image { get }
}

public struct ContextMenuModel {
    public let items: [ContextMenuItemGroup]
    
    public init(items: [ContextMenuItemGroup]) {
        self.items = items
    }
}

public struct ContextMenuItemGroup: Identifiable {
    public let id: String
    public internal(set) var items: [ContextMenuItem]
    
    public init(id: String, items: [ContextMenuItem]) {
        self.id = id
        self.items = items
    }
}

public struct ContextMenuItem: Identifiable {

    public enum Role {
        case `default`
        case destructive
    }

    public let identifier: String
    public let title: String
    public let icon: Image
    public let role: Role
    public let handler: () -> Void
    
    public var id: String {
        identifier
    }

    public init(
        sectionItem: SectionItemDisplayable,
        role: Role = .default,
        handler: @escaping () -> Void)
    {
        self.identifier = sectionItem.identifier
        self.title = sectionItem.text
        self.icon = sectionItem.icon
        self.role = role
        self.handler = handler
    }
}
