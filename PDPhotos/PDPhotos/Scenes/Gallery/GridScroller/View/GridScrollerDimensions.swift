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

struct GridScrollerDimensions {
    let scrollerPadding: CGFloat = 10
    let baseItemHeight: CGFloat = 22
    let bigItemHeight: CGFloat = 28
    let datesTrailingOffset: CGFloat = 72

    private let baseItemBottomPadding: CGFloat = 10
    private let topPadding: CGFloat = 52
    private let bottomPadding: CGFloat = 10
    private var totalVerticalPadding: CGFloat {
        topPadding + bottomPadding
    }

    func getAvailableCount(height: CGFloat) -> Int {
        let maximalHeight = height - totalVerticalPadding
        return Int(maximalHeight / (baseItemHeight + baseItemBottomPadding)) + 1
    }

    func getIndex(offset: CGFloat, screenHeight: CGFloat, itemsCount: Int) -> Int {
        guard itemsCount > 0 else {
            return 0
        }

        let height = screenHeight - totalVerticalPadding - baseItemHeight
        let normalizedOffset = offset - topPadding
        let approximateIndex = CGFloat(itemsCount - 1) * (normalizedOffset / height) - 0.5
        let index = Int(approximateIndex.rounded())
        return max(0, min(index, itemsCount - 1))
    }

    func makeTopOffset(viewHeight: CGFloat, screenHeight: CGFloat, index: Int, itemsCount: Int) -> CGFloat {
        guard itemsCount > 0 else {
            return 0
        }

        // We want compact capsule to have top at least at the minimalY and bottom at least at maximalY
        // Other (big capsule etc) need to respect the center of capsule, that's why we're counting center
        // and then adjusting by current view's height
        let halfOfBaseHeight = baseItemHeight / 2
        let minimalY = topPadding + halfOfBaseHeight
        let maximalY = screenHeight - bottomPadding - halfOfBaseHeight
        let availableSpace = maximalY - minimalY
        let singleStep = availableSpace / CGFloat(itemsCount - 1)
        let centerOfViewY = minimalY + CGFloat(index) * singleStep
        let normalizedCenterOfViewY = min(maximalY, max(minimalY, centerOfViewY))
        // Need to subtract half of the view since the offset is anchored to top of view
        let halfOfView = viewHeight / 2
        return normalizedCenterOfViewY - halfOfView
    }
}
