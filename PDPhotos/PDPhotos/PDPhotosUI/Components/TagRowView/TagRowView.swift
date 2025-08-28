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

import SwiftUI
import ProtonCoreUIFoundations

struct TagRowView: View {
    private let tags: [any Tag]
    private let singleSelection: Bool
    @State private var selectedTags: [any Tag] = []
    private var selectedTagDidChanged: ([any Tag]) -> Void

    init(tags: [any Tag], selectedTag: (any Tag)?, singleSelection: Bool = true, selectedTagDidChanged: @escaping ([any Tag]) -> Void) {
        self.tags = tags
        if let selected = selectedTag ?? tags.first {
            selectedTags = [selected]
        }
        self.singleSelection = singleSelection
        self.selectedTagDidChanged = selectedTagDidChanged
        
        if singleSelection && selectedTags.isEmpty {
            assertionFailure("Single selection assumes exactly 1 tag to be selected at all times")
        }
    }
    
    var body: some View {
        ScrollViewReader { value in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self.rawValue) { tag in
                        cell(tag: tag)
                            .id(tag.rawValue)
                    }
                }
                .padding(.horizontal, 16)
            }
            .accessibilityIdentifier("filter-scroll-view")
            .padding(.vertical, 8)
            .onAppear {
                // On appear scroll to selected tag
                if let selectedId = selectedTags.first?.rawValue {
                    value.scrollTo(selectedId)
                }
            }
        }
    }
    
    @ViewBuilder
    private func cell(tag: any Tag) -> some View {
        let identifier = isSelected(tag: tag) ? "filter-\(tag.identifier)-selected" : "filter-\(tag.identifier)"
        HStack(spacing: 4) {
            tag.icon
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(isSelected(tag: tag) ? ColorProvider.TextNorm : ColorProvider.IconWeak)
                .padding(.leading, 8)
            Text(tag.title)
                .font(.footnote)
                .fontWeight(isSelected(tag: tag) ? .bold : .regular)
                .foregroundStyle(isSelected(tag: tag) ? ColorProvider.TextNorm : ColorProvider.TextWeak)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
        }
        .background(isSelected(tag: tag) ? ColorProvider.BackgroundSecondary : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            select(tag: tag)
        }
        .accessibilityIdentifier(identifier)
    }

    private func isSelected(tag: any Tag) -> Bool {
        selectedTags.contains(where: { $0.rawValue == tag.rawValue })
    }

    private func select(tag: any Tag) {
        if singleSelection {
            if !selectedTags.contains(where: { $0.rawValue == tag.rawValue }) {
                selectedTags = [tag]
            }
        } else {
            if isSelected(tag: tag) {
                selectedTags.removeAll(where: { $0.rawValue == tag.rawValue })
            } else {
                selectedTags.append(tag)
            }
        }
        selectedTagDidChanged(selectedTags)
    }
}

#Preview("Photo tags") {
    TagRowView(
        tags: [PhotoUITag.all, .existing(.bursts), .existing(.favorites)],
        selectedTag: nil,
        selectedTagDidChanged: { tags in

        }
    )
}

#Preview("Album tags") {
    TagRowView(tags: AlbumUITag.allCases(), selectedTag: AlbumUITag.allCases()[safe: 1], selectedTagDidChanged: { tags in
        
    })
}
