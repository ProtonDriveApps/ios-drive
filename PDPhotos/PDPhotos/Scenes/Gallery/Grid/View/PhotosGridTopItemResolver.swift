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

import CoreGraphics

struct PhotosGridTopItemResolver {
    struct Layout {
        let columnCount: Int
        let itemWidth: CGFloat
        let itemAspectRatio: CGFloat
        let rowSpacing: CGFloat
        let sectionHeaderHeight: CGFloat
        let sectionFooterHeight: CGFloat
    }

    func resolveTopItem(sections: [PhotosGridViewSection], contentY: CGFloat, layout: Layout) -> PhotoGridViewItem? {
        guard
            !sections.isEmpty,
            layout.columnCount > 0,
            layout.itemWidth > 0,
            layout.itemAspectRatio > 0
        else {
            return nil
        }

        var sectionMinY: CGFloat = 0
        for (sectionIndex, section) in sections.enumerated() {
            let sectionHeight = makeSectionHeight(itemsCount: section.items.count, layout: layout)
            let sectionMaxY = sectionMinY + sectionHeight
            if contentY <= sectionMaxY || sectionIndex == sections.count - 1 {
                return resolveTopItem(in: section.items, contentY: contentY - sectionMinY, layout: layout)
            }
            sectionMinY = sectionMaxY
        }

        return nil
    }

    private func resolveTopItem(in items: [PhotoGridViewItem], contentY: CGFloat, layout: Layout) -> PhotoGridViewItem? {
        guard !items.isEmpty else {
            return nil
        }

        let itemHeight = layout.itemWidth / layout.itemAspectRatio
        let rowHeight = itemHeight + layout.rowSpacing
        let visibleOffset = max(0, contentY - layout.sectionHeaderHeight)
        let row = Int(visibleOffset / rowHeight)
        let index = min(row * layout.columnCount, items.count - 1)
        return items[index]
    }

    private func makeSectionHeight(itemsCount: Int, layout: Layout) -> CGFloat {
        let itemHeight = layout.itemWidth / layout.itemAspectRatio
        let rowsCount = CGFloat((itemsCount + layout.columnCount - 1) / layout.columnCount)
        let itemsHeight = rowsCount * itemHeight
        let spacingHeight = max(0, rowsCount - 1) * layout.rowSpacing
        return layout.sectionHeaderHeight + itemsHeight + spacingHeight + layout.sectionFooterHeight
    }
}
