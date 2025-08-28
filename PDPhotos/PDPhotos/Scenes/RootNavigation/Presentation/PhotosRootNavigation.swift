// Copyright (c) 2025 Proton AG
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

struct PhotosRootNavigation: Equatable {
    let title: String?
    let leading: Item?
    let trailing: [Item]

    static func `default`(isPaidUser: Bool, showTagMigrationSpinner: Bool) -> PhotosRootNavigation {
        var trailing: [Item] = []
        if !isPaidUser { trailing.append(.subscribe) }
        if showTagMigrationSpinner { trailing.append(.tagMigrationSpinner) }

        return .init(
            title: nil,
            leading: .menu,
            trailing: trailing
        )
    }

    static let picker = PhotosRootNavigation(
        title: nil,
        leading: .cross,
        trailing: []
    )

    enum Item: Equatable, Identifiable {
        case cross
        case menu
        case plus
        case cancel(String)
        case deselectAll(title: String, isEnabled: Bool)
        case subscribe
        case tagMigrationSpinner

        var id: String {
            switch self {
            case .cross:
                return "cross"
            case .menu:
                return "menu"
            case .plus:
                return "plus"
            case .cancel(let text):
                return "cancel_\(text)"
            case let .deselectAll(title, isEnabled):
                return "deselectAll_\(title)_\(isEnabled)"
            case .subscribe:
                return "subscribe"
            case .tagMigrationSpinner:
                return "tagMigrationSpinner"
            }
        }
    }
}
