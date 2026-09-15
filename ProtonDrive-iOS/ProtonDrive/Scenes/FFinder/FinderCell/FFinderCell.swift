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

import SwiftUI
import PDCoreIOS
import PDSDKCore
import ProtonCoreUIFoundations
import PDUIComponents
import PDLocalization

struct FFinderCell: View {
    @ObservedObject private var viewModel: FFinderCellViewModel
    private let index: Int
    private let layout: Layout
    private let onLongPress: (() -> Void)?
    private let onTap: (() -> Void)?
    private var isList: Bool { layout == .list }

    init(
        viewModel: FFinderCellViewModel,
        index: Int,
        layout: Layout,
        onTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.index = index
        self.layout = layout
        self.onTap = onTap
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        Group {
            if isList {
                listStyle
                    .padding(.leading)
                    .background(cellBackground)
            } else {
                gridStyle
                    .background(cellBackground.cornerRadius(8))
            }
        }
        .disabled(viewModel.state.shouldDisable)
        .opacity(viewModel.state.shouldDisable ? 0.5 : 1.0)
    }
    
    @ViewBuilder
    func thumbnail() -> some View {
        let placeholderSize: CGFloat = isList ? 40 : 48
        let frameSize: CGSize = isList ? .init(width: 40, height: 40) : .init(width: 155.5, height: 120)
        let thumbnailSize: CGSize = isList ? .init(width: 40, height: 40) : frameSize
        ZStack {
            Group {
                if let data = viewModel.thumbnail(), let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                        .cornerRadius(8)
                        .accessibilityIdentifier("thumbnail.image.\(viewModel.node.name)")
                } else {
                    FileAssetImageProvider.icon(for: viewModel.placeholderIconName)
                        .resizable()
                        .frame(width: placeholderSize, height: placeholderSize, alignment: .leading)
                        .accessibilityIdentifier("thumbnail.placeholder.\(viewModel.node.name)")
                }
            }
            .frame(width: frameSize.width, height: frameSize.height)
            .transition(.asymmetric(insertion: .slide, removal: .identity))

            if viewModel.state.isSharedWithMeRoot, let initial = viewModel.node.ownedBy?.first {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorProvider.Shade40)
                        .frame(width: 20, height: 20)
                    Text(String(initial).capitalized)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
                .offset(x: 5, y: 5)
                .accessibilityIdentifier("thumbnail.initial.\(viewModel.node.name)")
            }
        }
        .overlay {
            if !isList {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1))
                    .fill(ColorProvider.InteractionWeak)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !isList {
                HStack {
                    Spacer()
                    BadgeGroupView(
                        badges: viewModel.badges,
                        featureFlagsController: viewModel.dependencies.featureFlagsController,
                        isGridView: true,
                        parentIdentifier: "NodeListSecondLineView.\(viewModel.node.name)"
                    )
                    .padding(.trailing, 4)
                    .accessibilityElement(children: .contain)
                }
                .padding(.top, 12)
                .padding(.trailing, 4)
            }
        }
    }
    
    @ViewBuilder
    func selectionBox() -> some View {
        let iconSize: CGFloat = isList ? 18 : 10
        let viewSize: CGFloat = isList ? 21 : 13
        let isSelected = viewModel.isSelected
        if viewModel.isSelectionEnabled, !viewModel.node.isBookmark {
            RoundedSelectionView(isSelected: isSelected, iconSize: iconSize, viewSize: viewSize)
                .transition(.asymmetric(insertion: .slide, removal: .identity))
                .accessibility(identifier: "selectionButton.\(viewModel.node.name)")
                .accessibilityLabel(isSelected ? "selected" : "unselected")
                .modifier(SelectionAnimationModifier(isSelected: isSelected))
        }
    }
    
    var cellBackground: some View {
        viewModel.isSelected ? ColorProvider.BackgroundSecondary : ColorProvider.BackgroundNorm
    }
}

// MARK: - List layout
extension FFinderCell {
    var listStyle: some View {
        VStack {
            HStack(spacing: 12) {
                interactiveArea {
                    HStack(spacing: 12) {
                        selectionBox()
                            .frame(width: 40, height: 40)
                        thumbnail()
                        listDetailsView()
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(Localization.accessibility_open_file(fileName: viewModel.node.name))
                }
                actions(modifier: ContextMenuListModifier())
            }
            separator()
        }
        .frame(height: 74)
    }
    
    @ViewBuilder
    func listDetailsView() -> some View {
        let name = viewModel.node.name
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            
            Text(name)
                .truncationMode(viewModel.node.isFolder ? .tail : .middle)
                .foregroundColor(ColorProvider.TextNorm)
                .lineLimit(1)
                .accessibility(identifier: "NodeCell.Text.\(name)")
                .accessibilityLabel("\(name)_\(index)")

            HStack(spacing: 0) {
                NodeListSecondLineView(
                    vm: viewModel.secondLine,
                    parentIdentifier: "NodeListSecondLineView.\(name)",
                    featureFlagsController: viewModel.dependencies.featureFlagsController
                )
                .accessibilityElement(children: .contain)
                Spacer()
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    func separator() -> some View {
        switch viewModel.separator {
        case .divider:
            Spacer()
                .frame(height: 1.0)
        case .progressing(let progress):
            ProgressBar(
                value: .init(get: { progress }, set: { _ in }),
                offset: 0,
                foregroundColor: ColorProvider.BrandNorm,
                backgroundColor: ColorProvider.SeparatorNorm
            )
            .frame(maxWidth: .infinity)
            .frame(height: 1.0)
            .accessibility(identifier: "ProgressBar.uploadingOrDownloading")
        }
    }
}

// MARK: - Grid layout
extension FFinderCell {
    var gridStyle: some View {
        VStack(spacing: 8) {
            interactiveArea {
                thumbnail()
            }
            HStack {
                interactiveArea {
                    gridNameLabel
                        .accessibilityHidden(true)
                }
                Spacer()
                gridButton()
                    .frame(height: 24)
                    .animation(nil, value: false)
                    .contentShape(Rectangle())
                    .padding(.trailing, 3)
                    .accessibility(identifier: "FinderGridCell.GridButton.\(viewModel.node.name)")
            }
            .padding(.horizontal, 12)
        }
        .accessibilityElement(children: .contain)
        .frame(width: GridCellConstants.gridCellSize.width, height: GridCellConstants.gridCellSize.height)
    }
    
    var gridNameLabel: some View {
        Text(viewModel.node.name)
            .lineLimit(1)
            .font(.footnote)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 8)
            .accessibility(identifier: "FinderGridCell.Text.\(viewModel.node.name)")
            .accessibilityLabel("\(viewModel.node.name)_\(index)")
    }
    
    @ViewBuilder
    func gridButton() -> some View {
        if viewModel.isInProgress && viewModel.progressDirection == .downstream {
            HStack {
                Text(viewModel.progressPercentage)
                    .font(.caption)
                    .foregroundColor(ColorProvider.TextWeak)

                ProtonSpinner(size: .small)
            }
        } else if viewModel.isSelectionEnabled {
            selectionBox()
                .onTapGesture { onTap?() }
        } else {
            actions(modifier: EmptyModifier())
        }
    }
}

// MARK: - Gestures
private extension FFinderCell {
    @ViewBuilder
    func interactiveArea<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let view = content().contentShape(Rectangle())
        if let onTap, let onLongPress {
            view
                .onTapGesture(perform: onTap)
                .onLongPressGesture(perform: onLongPress)
        } else if let onTap {
            view
                .onTapGesture(perform: onTap)
        } else if let onLongPress {
            view
                .onLongPressGesture(perform: onLongPress)
        } else {
            view
        }
    }
}

// MARK: - More actions
extension FFinderCell {
    @ViewBuilder
    func actions<Modifier: ViewModifier>(modifier: Modifier) -> some View {
        if !viewModel.isSelectionEnabled {
            HStack(spacing: 0) {
                let name = viewModel.node.name
                ForEach(viewModel.buttons, id: \.type) { button in
                    switch button.type {
                    case .menu:
                        contextMenu(button, modifier: modifier)
                            .accessibility(identifier: "NodeCellButton.three-dots-horizontal.\(name)")
                            .accessibilityLabel(Localization.accessibility_more_menu_action(fileName: name))
                    case .trash(let nodeIdentifier):
                        // TODO: finder-refactor, implement for trash view
                        contextMenu(button, modifier: modifier)
                    case .cancel:
                        defaultCellButton(button)
                            .accessibility(identifier: "NodeCellButton.cancel.\(name)")
                    case .retry:
                        defaultCellButton(button)
                            .padding(.trailing, 8) // To align with context menu
                            .accessibility(identifier: "NodeCellButton.retry.\(name)")
                    }
                }
            }
        }
    }
    
    private func defaultCellButton(_ button: NodeCellButton) -> some View {
        Button(action: button.action, label: {
            button.icon
                .accentColor(ColorProvider.TextNorm)
                .frame(width: 40, height: 40, alignment: .center)
        })
        .frame(width: 40, height: 40)
    }
    
    @ViewBuilder
    private func contextMenu<Modifier: ViewModifier>(_ button: NodeCellButton, modifier: Modifier) -> some View {
        ContextMenuView(icon: button.icon, viewModifier: modifier) {
            if viewModel.isInProgress {
                uploadingNodeMoreActions()
            } else {
                commonNodeMoreActions()
            }
        }
    }

    @ViewBuilder
    private func commonNodeMoreActions() -> some View {
        ForEach(
            viewModel.editActionGroups(),
            id: \.id
        ) { group in
            ForEach(group.items, id: \.id) { item in
                ContextMenuItemActionView(item: item)
            }
            Divider()
        }

        if let moreActionGroup = viewModel.moreActionGroup {
            ForEach(moreActionGroup.items, id: \.id) { item in
                ContextMenuItemActionView(item: item)
            }
        }
    }

    @ViewBuilder
    private func uploadingNodeMoreActions() -> some View {
        if let group = viewModel.uploadActionGroup {
            ForEach(group.items, id: \.id) { item in
                ContextMenuItemActionView(item: item)
            }
        }
    }
}

private struct ContextMenuListModifier: ViewModifier {
    private let horizontalInset: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(.vertical)
            .padding(.horizontal, horizontalInset)
    }
}
