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

enum PhotoUITag: Tag {
    case all
    case existing(PhotoTag)

    var rawValue: String? {
        switch self {
        case .all:
            return nil
        case .existing(let tag):
            return "\(tag.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .all:
            return Localization.tag_all
        case .existing(let tag):
            switch tag {
            case .favorites:
                return Localization.tag_favorites
            case .videos:
                return Localization.tag_videos
            case .livePhotos:
                return Localization.tag_livePhotos
            case .motionPhotos:
                return Localization.tag_motionPhotos
            case .bursts:
                return Localization.tag_burst
            case .selfies:
                return Localization.tag_selfies
            case .screenshots:
                return Localization.tag_screenshots
            case .portraits:
                return Localization.tag_portraits
            case .panoramas:
                return Localization.tag_panoramas
            case .raw:
                return Localization.tag_raw
            }
        }
    }

    var icon: Image {
        switch self {
        case .all:
            return IconProvider.image
        case .existing(let tag):
            switch tag {
            case .favorites:
                return IconProvider.heart
            case .videos:
                return InternalIcon.videoCamera
            case .livePhotos:
                return InternalIcon.livePhoto
            case .motionPhotos:
                return InternalIcon.livePhoto
            case .bursts:
                return InternalIcon.burst
            case .selfies:
                return IconProvider.userCircle
            case .screenshots:
                return InternalIcon.screenshot
            case .portraits:
                return InternalIcon.portrait
            case .panoramas:
                return InternalIcon.panoramas
            case .raw:
                return InternalIcon.raw
            }
        }
    }

    var tag: PhotoTag? {
        switch self {
        case .all:
            return nil
        case let .existing(photoTag):
            return photoTag
        }
    }

    var identifier: String {
        switch self {
        case .all:
            return "all"
        case .existing(let tag):
            switch tag {
            case .favorites:
                return "favorites"
            case .videos:
                return "videos"
            case .livePhotos:
                return "livePhotos"
            case .motionPhotos:
                return "motionPhotos"
            case .bursts:
                return "bursts"
            case .selfies:
                return "selfies"
            case .screenshots:
                return "screenshots"
            case .portraits:
                return "portraits"
            case .panoramas:
                return "panoramas"
            case .raw:
                return "raw"
            }
        }
    }
}
