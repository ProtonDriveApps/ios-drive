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
import PDLocalization
import PDUIComponents
import ProtonCoreUIFoundations

/// Composes the UICollectionView-backed grid with the same overlays the SwiftUI
/// `PhotosGridView` provides: the scrubber, navigation toolbar, banners, action
/// bar, floating selection-confirm (picker mode), and error toast.
struct PhotosCollectionGridView<
    ActionView: View,
    BannersView: View,
    ScrollerView: View,
    ItemView: View
>: View {
    @ObservedObject private var viewModel: PhotosGridViewModel
    private let navigationFactory: PhotosRootNavigationButtonFactory
    private let actionView: ActionView
    private let bannersView: BannersView
    private let scrollerView: ScrollerView
    private let item: (PhotoGridViewItem, String) -> ItemView

    @ObservedObject private var zoomController: PhotosGridZoomController

    @State private var isScrolled = false
    @State private var bottomInset: CGFloat = 0

    init(
        viewModel: PhotosGridViewModel,
        navigationFactory: PhotosRootNavigationButtonFactory,
        zoomController: PhotosGridZoomController,
        actionView: ActionView,
        bannersView: BannersView,
        scrollerView: ScrollerView,
        item: @escaping (PhotoGridViewItem, String) -> ItemView
    ) {
        self.viewModel = viewModel
        self.navigationFactory = navigationFactory
        self.zoomController = zoomController
        self.actionView = actionView
        self.bannersView = bannersView
        self.scrollerView = scrollerView
        self.item = item
    }

    var body: some View {
        gridContentWithToolbar
            .overlay(alignment: .bottom) {
                bottomOverlay
            }
            .errorToast(location: .bottom, errors: viewModel.error)
    }

    @ViewBuilder
    private var gridContentWithToolbar: some View {
        if #available(iOS 26.0, *) {
            gridContent
                .toolbar {
                    if viewModel.navigation != nil {
                        navigationFactory.makeGlassToolbar(
                            navigation: viewModel.navigation,
                            block: viewModel.handle(navigation:)
                        )
                    } else {
                        // No item selected, show toolbar button instead
                        viewOptionsToolbarItem
                    }
                }
        } else {
            gridContent
                .toolbar {
                    if viewModel.navigation != nil {
                        navigationFactory.makeLegacyToolbar(
                            navigation: viewModel.navigation,
                            block: viewModel.handle(navigation:)
                        )
                    } else {
                        // No item selected, show toolbar button instead
                        viewOptionsToolbarItem
                    }
                }
        }
    }

    private var gridContent: some View {
        ZStack(alignment: .trailing) {
            PhotosCollectionView(
                viewModel: viewModel,
                item: item,
                zoomController: zoomController,
                bottomContentInset: bottomInset,
                showsScrollIndicator: !viewModel.isUsingCustomScroller,
                onScrolledChanged: { scrolled in
                    withAnimation { isScrolled = scrolled }
                }
            )
            scrollerView
        }
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        if viewModel.configuration.isPickingPhotos {
            floatingSelectionConfirmView
                .background(insetReader)
        } else {
            VStack(spacing: 0) {
                if !isScrolled {
                    bannersView
                }
                actionView
            }
            .background(insetReader)
        }
    }

    /// Measures the bottom overlay's height and feeds it back as a content inset,
    /// mirroring `PhotosGridView`'s `paddingView` / `bottomPadding`.
    private var insetReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { bottomInset = proxy.size.height }
                .onChange(of: proxy.size) { _ in bottomInset = proxy.size.height }
        }
    }

    private var floatingSelectionConfirmView: some View {
        FloatingConfirmSelectionButton(
            selectionNumber: .init(get: { viewModel.selectionNumber }, set: { _ in }),
            cancelAction: { viewModel.deselectAll() },
            addAction: { viewModel.selectionFinalized() }
        )
    }

    private var viewOptionsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    viewModel.startSelecting()
                } label: {
                    Text(Localization.general_select)
                }
                .accessibilityIdentifier("PhotosGridView.ViewOptionsMenu.Select")
                .disabled(viewModel.isSelecting)
                
                Section(Localization.photos_view_options) {
                    Button {
                        zoomController.zoomIn()
                    } label: {
                        Label {
                            Text(Localization.photos_zoom_in)
                        } icon: {
                            Image(uiImage: IconProvider.plus)
                        }
                    }
                    .disabled(!zoomController.canZoomIn)
                    .accessibilityIdentifier("PhotosGridView.ViewOptionsMenu.ZoomIn")

                    Button {
                        zoomController.zoomOut()
                    } label: {
                        Label {
                            Text(Localization.photos_zoom_out)
                        } icon: {
                            Image(uiImage: IconProvider.minus)
                        }
                    }
                    .disabled(!zoomController.canZoomOut)
                    .accessibilityIdentifier("PhotosGridView.ViewOptionsMenu.ZoomOut")
                }
            } label: {
                Image(uiImage: IconProvider.sliders)
                    .foregroundStyle(ColorProvider.IconNorm)
            }
            .accessibilityLabel(Localization.photos_grid_options)
            .accessibilityIdentifier("PhotosGridView.NavigationBarButton.ViewOptions")
        }
    }

}
