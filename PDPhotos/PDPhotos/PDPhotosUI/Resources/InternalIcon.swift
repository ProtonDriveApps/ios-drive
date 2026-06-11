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

struct ImageSet {
    static let instance = ImageSet()

    let coverPlaceholder = ImageIcon(name: "cover_placeholder")
    let playFilled = ImageIcon(name: "ic-play-filled")
    let playFilledBackground = ImageIcon(name: "ic-play-filled-background")
    let burst = ImageIcon(name: "ic-burst")
    let arrowDownWhite = ImageIcon(name: "arrow-down-white")
    let arrowDownBackground = ImageIcon(name: "ic-arrow-down-background")
    let ellipseDotted = ImageIcon(name: "ellipse-dotted")
    let users = ImageIcon(name: "ic-users-filled")
    let linkFilledBackground = ImageIcon(name: "ic-link-filled-background")
    let listArrowDown = ImageIcon(name: "ic-list-arrow-down")
    let videoCamera = ImageIcon(name: "ic-video-camera")
    let livePhoto = ImageIcon(name: "ic-live")
    let screenshot = ImageIcon(name: "ic-screenshot")
    let panoramas = ImageIcon(name: "ic-panoramas")
    let raw = ImageIcon(name: "ic-raw")
    let iconsBackground = ImageIcon(name: "icons-background")
    let videoBackground = ImageIcon(name: "video-background")
    let cloudSlash = ImageIcon(name: "ic-cloud-slash")
    let noConnection = ImageIcon(name: "ic-no-connection")
    let heartFilled = ImageIcon(name: "ic-heart-filled")
    let userPlusFilled = ImageIcon(name: "ic-user-plus-filled")
    let image = ImageIcon(name: "ic-image")
    let albumFrame = ImageIcon(name: "ic-album-frame")
    let cloudArrowDown = ImageIcon(name: "ic-cloud-arrow-down")
    let fileAlbumNoPadding = ImageIcon(name: "ic-file-album-no-padding")
    let chevronUpDown = ImageIcon(name: "ic-chevron-up-down")
    let portrait = ImageIcon(name: "ic-portrait")
    // Illustrations
    let photosOnboarding = ImageIcon(name: "photos_onboarding")
    let photosOnboardingOld = ImageIcon(name: "photos_onboarding_old")
    let allPhotos = ImageIcon(name: "illustration_allPhotos")
    let photoUpsell = ImageIcon(name: "photo-upsell")
    let albumIllustration = ImageIcon(name: "illustration-album")
    let tagMigrationSheetIllustration = ImageIcon(name: "illustration_tagMigrationSheet")
}

struct ImageIcon {
    var name: String
}

@dynamicMemberLookup
final class IconLookup { }

#if canImport(UIKit)
import UIKit

extension IconLookup {
    subscript(dynamicMember keyPath: KeyPath<ImageSet, ImageIcon>) -> UIImage {
        return ImageSet.instance[keyPath: keyPath].uiImage ?? UIImage()
    }
}

private extension ImageIcon {
    var uiImage: UIImage? {
        UIImage(named: name, in: .module, with: nil)
    }
}
#endif

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
extension IconLookup {
    subscript(dynamicMember keyPath: KeyPath<ImageSet, ImageIcon>) -> Image {
        return ImageSet.instance[keyPath: keyPath].image
    }
}

private extension ImageIcon {
    var image: Image {
        Image(name, bundle: .module)
    }
}
#endif

let InternalIcon = IconLookup()
