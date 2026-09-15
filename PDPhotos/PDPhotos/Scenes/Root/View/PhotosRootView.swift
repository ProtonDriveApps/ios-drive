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

import PDCore
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct PhotosRootView<
    ViewModel: PhotosRootViewModelProtocol,
    Gallery: View,
    Albums: View
>: View  {
    @ObservedObject private var viewModel: ViewModel
    @EnvironmentObject var root: RootViewModel
    private let navigationFactory: PhotosRootNavigationButtonFactory
    private let gallery: (PhotoStreamConfiguration) -> Gallery
    private let albums: (PhotoStreamConfiguration) -> Albums

    init(
        viewModel: ViewModel,
        navigationFactory: PhotosRootNavigationButtonFactory,
        gallery: @escaping (PhotoStreamConfiguration) -> Gallery,
        albums: @escaping (PhotoStreamConfiguration) -> Albums
    ) {
        self.viewModel = viewModel
        self.navigationFactory = navigationFactory
        self.gallery = gallery
        self.albums = albums
    }

    var body: some View {
        contentWithToolbar
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: viewModel.start)
            .onReceive(root.closeCurrentSheet) { _ in
                viewModel.close()
            }
    }

    // The availability branch lives here, in a `@ViewBuilder`, and never inside the
    // `@ToolbarContentBuilder` properties below — see `PhotosRootNavigationButtonFactory`.
    @ViewBuilder
    private var contentWithToolbar: some View {
        if #available(iOS 26.0, *) {
            content.toolbar { glassToolbarContent }
        } else {
            content.toolbar { legacyToolbarContent }
        }
    }

    @available(iOS 26.0, *)
    @ToolbarContentBuilder
    private var glassToolbarContent: some ToolbarContent {
        let block = viewModel.handle(navigation:)
        if let navigation = viewModel.navigation {
            if navigation.title != nil {
                navigationFactory.makeGlassToolbar(navigation: navigation, block: block)
            } else {
                navigation.leading.map { item in
                    navigationFactory.makeGlassToolbarItems(items: [item], placement: .topBarLeading, block: block)
                }
                NavigationTitleView()
                    .title(isEnabled: viewModel.areAlbumsEnabled, placement: .title, selected: galleryTypeBinding)
                navigationFactory.makeGlassToolbarItems(
                    items: navigation.trailing,
                    placement: .topBarTrailing,
                    block: block
                )
            }
        }
    }

    @ToolbarContentBuilder
    private var legacyToolbarContent: some ToolbarContent {
        let block = viewModel.handle(navigation:)
        if let navigation = viewModel.navigation {
            if navigation.title != nil {
                navigationFactory.makeLegacyToolbar(navigation: navigation, block: block)
            } else {
                navigation.leading.map { item in
                    navigationFactory.makeLegacyToolbarItems(items: [item], placement: .topBarLeading, block: block)
                }
                // `.title` placement is iOS 26+; `.principal` is the pre-26 equivalent.
                NavigationTitleView()
                    .title(isEnabled: viewModel.areAlbumsEnabled, placement: .principal, selected: galleryTypeBinding)
                navigationFactory.makeLegacyToolbarItems(
                    items: navigation.trailing,
                    placement: .topBarTrailing,
                    block: block
                )
            }
        }
    }

    private var galleryTypeBinding: Binding<GalleryType> {
        Binding(
            get: { viewModel.galleryType },
            set: { viewModel.handle(galleryType: $0) }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProtonSpinner(size: .medium, isHugging: true)
        case .finished(let streamConfiguration):
            switch viewModel.galleryType {
            case .photos:
                gallery(streamConfiguration)
                    .onAppear {
                        viewModel.onAppear(streamConfiguration: streamConfiguration)
                    }
            case .albums:
                albums(streamConfiguration)
            }
        case let .message(text):
            NoConnectionView(
                isUpdating: .constant(false),
                config: PlaceholderViewConfiguration(image: .type(.genericError), title: text, message: ""),
                refresh: viewModel.start
            )
        }
    }
}
