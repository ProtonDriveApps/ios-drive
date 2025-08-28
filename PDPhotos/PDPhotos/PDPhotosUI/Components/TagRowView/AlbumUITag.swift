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
import PDLocalization
import ProtonCoreUIFoundations
import SwiftUI

enum AlbumUITag: Tag {
    case all
    case existing(AlbumTag)

    static func allCases() -> [AlbumUITag] {
        var cases: [AlbumUITag] = [.all]
        cases.append(contentsOf: AlbumTag.allCases.map { AlbumUITag.existing($0) })
        return cases
    }

    var rawValue: String? {
        switch self {
        case .all: return nil
        case .existing(let tag):
            return "\(tag.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .all: return Localization.tag_all
        case .existing(let tag):
            switch tag {
            case .myAlbums: return Localization.tag_myAlbum
            case .shared: return Localization.tag_shared
            case .sharedWithMe: return Localization.tag_sharedWithMe
            }
        }
    }

    var icon: Image {
        switch self {
        case .all:
            return InternalIcon.albumFrame
        case .existing(let tag):
            switch tag {
            case .myAlbums:
                return IconProvider.user
            case .shared:
                return IconProvider.link
            case .sharedWithMe:
                return IconProvider.users
            }
        }
    }

    var identifier: String {
        switch self {
        case .all: return "all"
        case .existing(let tag):
            switch tag {
            case .myAlbums: return "myAlbums"
            case .shared: return "shared"
            case .sharedWithMe: return "sharedWithMe"
            }
        }
    }
}
