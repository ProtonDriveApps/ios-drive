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

import UIKit

enum PhotosGridLayoutFactory {
    static let defaultItemWidth: CGFloat = 128
    static let minItemWidth: CGFloat = 32
    
    // Floor for zooming in
    static let minimumNumberOfColumns = 2 // 1 would make the images blury due to usage of lowres thumbnails
    
    // Initial number of columns
    static let defaultMinimumColumns = 3
    static let spacing: CGFloat = 1.5

    static let itemAspectRatio: CGFloat = 1 / 1.4
    static let headerHeight: CGFloat = 45
    static let interSectionSpacing: CGFloat = 10
    static let footerElementKind = "PhotosGridFooter"

    static func make(columns: Int? = nil, preferableItemWidth: CGFloat = defaultItemWidth) -> UICollectionViewCompositionalLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = interSectionSpacing
        // A single footer after all sections — pagination status + E2E label.
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64)),
            elementKind: footerElementKind,
            alignment: .bottom)
        config.boundarySupplementaryItems = [footer]
        return UICollectionViewCompositionalLayout(sectionProvider: { _, environment in
            let width = environment.container.effectiveContentSize.width
            return makeSection(
                width: width,
                columns: columns ?? numberOfColumns(width: width, preferableItemWidth: preferableItemWidth)
            )
        }, configuration: config)
    }

    static func numberOfColumns(
        width: CGFloat,
        preferableItemWidth: CGFloat,
        minimumColumns: Int = defaultMinimumColumns
    ) -> Int {
        let threshold = preferableItemWidth * CGFloat(minimumColumns + 1)
                      + spacing * CGFloat(minimumColumns - 1)
        guard width >= threshold else { return minimumColumns }
        return max(minimumColumns, Int((width + spacing) / (preferableItemWidth + spacing)))
    }

    private static func makeSection(width: CGFloat, columns requestedColumns: Int) -> NSCollectionLayoutSection {
        let columns = max(requestedColumns, minimumNumberOfColumns)
        let itemWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let itemHeight = itemWidth / itemAspectRatio // = itemWidth * 1.4

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(itemWidth),
            heightDimension: .absolute(itemHeight))
        let items = (0..<columns).map { _ in NSCollectionLayoutItem(layoutSize: itemSize) }
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(itemHeight)),
            subitems: items)
        group.interItemSpacing = .fixed(spacing)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(headerHeight)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top)
        header.pinToVisibleBounds = true // replaces LazyVGrid's pinnedViews: [.sectionHeaders]
        section.boundarySupplementaryItems = [header]
        return section
    }
}
