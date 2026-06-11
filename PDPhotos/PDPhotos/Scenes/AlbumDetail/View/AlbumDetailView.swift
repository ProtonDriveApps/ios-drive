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

import SwiftUI
import ProtonCoreUIFoundations
import PDUIComponents

struct AlbumDetailView<ActionView: View>: View {
    @ObservedObject private var viewModel: AlbumDetailViewModel
    @State private var scrollViewOffset: CGFloat = 0
    private let actionView: ActionView
    private let coverHeight: CGFloat = 226

    init(viewModel: AlbumDetailViewModel, actionView: ActionView) {
        self.viewModel = viewModel
        self.actionView = actionView
    }

    var body: some View {
        GeometryReader { geometry in
            content(geometry: geometry)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .background(.clear)
    }

    private func content(geometry: GeometryProxy) -> some View {
        ZStack {
            AlbumDetailCoverView(scrollViewOffset: scrollViewOffset, viewModel: viewModel.getCoverViewModel())
            detailLayer(geometry: geometry)
        }
        .toolbar(content: {
            titleView
            trailingButton
            leadingButton
        })
        .navigationTitle(viewModel.navigationTitle)
        .ignoresSafeArea(.all, edges: .top)
        .navigationBarBackButtonHidden(true)
        .overlay(alignment: .bottom) {
            if viewModel.configuration.isPickingPhotos {
                floatingSelectionConfirmView
            } else {
                actionView
            }
        }
    }
}

// MARK: - Tool bar
extension AlbumDetailView {

    @ToolbarContentBuilder
    var trailingButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            switch viewModel.trailingItem {
            case .cancel:
                cancelButton
            case .empty:
                EmptyView()
            default:
                moreButton
            }
        }
    }

    var moreButton: some View {
        Button {
            viewModel.tapMore()
        } label: {
            if viewModel.isDeletingAlbum {
                ProtonSpinner(size: .custom(24), style: .inverted)
            } else {
                Image(uiImage: IconProvider.threeDotsVertical)
                    .renderingMode(.template)
                    .foregroundStyle(.white)
            }
        }
        .disabled(viewModel.isDeletingAlbum)
        .accessibilityIdentifier("AlbumDetailView.MoreButton")
    }

    var cancelButton: some View {
        Button {
            viewModel.tapCancelSelection()
        } label: {
            Text(AlbumDetailConstants.cancel)
                .foregroundStyle(.white)
                .font(.body.bold())
        }
        .accessibilityIdentifier("AlbumDetailView.CancelButton")
    }

    @ToolbarContentBuilder
    var leadingButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            switch viewModel.leadingItem {
            case .deselectAll:
                deselectAllButton
            case .back:
                backButton
            default:
                EmptyView()
            }
        }
    }

    var deselectAllButton: some View {
        Button {
            viewModel.deselectAll()
        } label: {
            Text(AlbumDetailConstants.deselectAll)
                .foregroundStyle(viewModel.selectionNumber == 0 ? ColorProvider.TextDisabled : .white)
                .font(.body.bold())
        }
        .accessibilityIdentifier("AlbumDetailView.DeselectAll")
        .disabled(viewModel.selectionNumber == 0)
    }

    var backButton: some View {
        Button {
            viewModel.tapBack()
        } label: {
            IconProvider.arrowLeft
                .renderingMode(.template)
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier("navigationBar.backButton")
    }

    @ToolbarContentBuilder
    var titleView: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if viewModel.showSpinner {
                ProtonSpinner(size: .custom(24), style: .inverted)
                    .accessibilityIdentifier("AlbumDetailView.pullToRefresh.spinner")
            } else {
                Text(viewModel.title(offset: scrollViewOffset))
                    .font(.title3)
                    .foregroundStyle(.white.opacity(titleOpacity()))
                    .accessibilityIdentifier("AlbumDetailView.pullToRefresh.text")
            }
        }
    }

    private var floatingSelectionConfirmView: some View {
        FloatingConfirmSelectionButton(
            selectionNumber: .init(get: { viewModel.selectionNumber }, set: { _ in }),
            cancelAction: { viewModel.deselectAll() },
            addAction: { viewModel.selectionFinalized() }
        )
    }

    private func titleOpacity() -> Double {
        if scrollViewOffset < 0 {
            return 0
        } else if scrollViewOffset > 50 {
            return 1
        } else {
            return scrollViewOffset / 50.0
        }
    }
}

// MARK: - Album container
extension AlbumDetailView {
    @ViewBuilder
    private func detailLayer(geometry: GeometryProxy) -> some View {
        let topInset = geometry.safeAreaInsets.top
        let dateRowHeight: CGFloat = 40
        VStack(spacing: 0) {
            Rectangle()
                .fill(.clear)
                .frame(height: topInset)
            OffsettableScrollView { point in
                scrollViewOffset = point.y
                viewModel.offsetIsChanged(offset: point.y)
            } content: { _ in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: geometry.size.width, height: coverHeight - topInset - dateRowHeight)
                    container(geometry: geometry)
                        .frame(maxHeight: .infinity)
                }
            }
            .clipped()
            .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16))
        }
    }

    @ViewBuilder
    private func container(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            AlbumDetailInfoView(viewModel: viewModel.getInfoViewModel(), isAddingPhotos: viewModel.isAddingPhotos)
                .onVisibilityChange(topInset: geometry.safeAreaInsets.top, perform: { isVisible in
                    viewModel.showNavigationTitle = !isVisible
                })
                .padding(.horizontal, 18)

            AlbumDetailGridView(viewModel: viewModel.getGridViewModel())
                .padding(.top, 8)
                .padding(.horizontal, 16)
        }
        .background(ColorProvider.BackgroundNorm)
        .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16))
    }
}

private extension View {

    func onVisibilityChange(topInset: CGFloat, perform action: @escaping (Bool) -> Void) -> some View {
        modifier(VisibilityMonitor(action: action, topInset: topInset))
    }
}

// Not general monitor, only suitable for this view
private struct VisibilityMonitor: ViewModifier {
    @State var action: ((Bool) -> Void)?
    let topInset: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .global)) { _ in
                        let frame = proxy.frame(in: .global)
                        let isHidden = topInset - frame.minY >= frame.size.height
                        action?(!isHidden)
                    }
            }
        }
    }
}
