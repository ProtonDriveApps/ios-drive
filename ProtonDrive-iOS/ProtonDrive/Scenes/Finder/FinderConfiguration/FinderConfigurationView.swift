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

import SwiftUI
import ProtonCoreUIFoundations
import PDCore

struct FinderConfigurationView: View {
    let sortingText: String?
    let switchSorting: ((SortPreference) -> Void)?
    let sorting: SortPreference
    let layout: Layout
    let changeLayout: (() -> Void)?
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Menu {
                    Button {
                        switchSortPreference(ascending: .nameAscending, descending: .nameDescending)
                    } label: {
                        menuItem(name: "Name", ascending: .nameAscending, descending: .nameDescending)
                    }
                    
                    Button {
                        switchSortPreference(ascending: .modifiedAscending, descending: .modifiedDescending)

                    } label: {
                        menuItem(name: "Last modified", ascending: .modifiedAscending, descending: .modifiedDescending)
                    }
                    
                    Button {
                        switchSortPreference(ascending: .sizeAscending, descending: .sizeDescending)
                    } label: {
                        menuItem(name: "Size", ascending: .sizeAscending, descending: .sizeDescending)
                    }
                    
                    Button {
                        switchSortPreference(ascending: .mimeAscending, descending: .mimeDescending)
                    } label: {
                        menuItem(name: "File type", ascending: .mimeAscending, descending: .mimeDescending)
                    }
                } label: {
                    HStack {
                        if let sortingText = sortingText {
                            Text(sortingText)
                                .foregroundColor(ColorProvider.TextWeak)
                                .multilineTextAlignment(.leading)
                        }
                        IconProvider.chevronDown
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(hasSorting ? ColorProvider.IconHint : ColorProvider.BackgroundNorm)
                            .rotationEffect(Angle(degrees: sorting.isAscending ? 180 : 0))
                            .accessibilityLabel(sorting.isAscending ? "ascending" : "descending")
                        Spacer()
                    }
                    .font(.footnote)
                    .accessibilityIdentifier("Menu.SortingSelection")
                }
                .disabled(!hasSorting)

                Button(action: { changeLayout?() }, label: {
                    layout.nextImage
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(ColorProvider.IconWeak)
                        .opacity(hasLayout ? 1.0 : 0.5)
                })
                .disabled(!hasLayout)
                .accessibility(identifier: "Button.LayoutSwitcher")
            }
        }
        .background(ColorProvider.BackgroundNorm)
    }
    
    private func switchSortPreference(ascending: SortPreference, descending: SortPreference) {
        let next: SortPreference = sorting == ascending ? descending : ascending
        switchSorting?(next)
    }
    
    private func menuItem(name: String, ascending: SortPreference, descending: SortPreference) -> some View {
        Label {
            Text(name)
        } icon: {
            arrowIcon(ascending, descending)
        }
    }

    private func arrowIcon(_ ascending: SortPreference, _ descending: SortPreference) -> Image {
        sorting == ascending ? arrowUp : sorting == descending ? arrowDown : Image("")
    }

    private var arrowUp: Image {
        IconProvider.arrowUp
    }

    private var arrowDown: Image {
        IconProvider.arrowDown
    }

    func menuGroup() -> some View {
        Button(action: { changeLayout?() }, label: {
            layout.nextImage
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundColor(ColorProvider.IconWeak)
                .opacity(hasLayout ? 1.0 : 0.5)
        })
        .disabled(!hasLayout)
        .accessibility(identifier: "Button.LayoutSwitcher")
    }
    
    private var hasSorting: Bool {
        switchSorting != nil
    }
    
    private var hasLayout: Bool {
        changeLayout != nil
    }
}

extension Layout {
    var nextImage: Image {
        switch self {
        case .grid:
            return IconProvider.listBullets
        case .list:
            return IconProvider.grid2
        }
    }
}
