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

struct GridConfiguration {
    let aspectRatio: CGFloat
    let minimumNumberOfColumns: CGFloat
    let preferableItemWidth: CGFloat
    let hSpacing: CGFloat
    let vSpacing: CGFloat

    init(
        aspectRatio: CGFloat,
        minimumNumberOfColumns: CGFloat,
        preferableItemWidth: CGFloat,
        hSpacing: CGFloat,
        vSpacing: CGFloat
    ) {
        self.minimumNumberOfColumns = minimumNumberOfColumns
        self.preferableItemWidth = preferableItemWidth
        self.hSpacing = hSpacing
        self.vSpacing = vSpacing
        self.aspectRatio = aspectRatio
    }
}

extension GridConfiguration {
    static func album() -> Self {
        .init(aspectRatio: 160 / 207.77, minimumNumberOfColumns: 2, preferableItemWidth: 160, hSpacing: 17, vSpacing: 18)
    }

    static func photosInAlbum() -> Self {
        .init(aspectRatio: 108 / 146, minimumNumberOfColumns: 3, preferableItemWidth: 108, hSpacing: 10, vSpacing: 10)
    }

    static func photoGallery() -> Self {
        .init(aspectRatio: 124 / 166, minimumNumberOfColumns: 3, preferableItemWidth: 124, hSpacing: 1.5, vSpacing: 1.5)
    }
}
