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

import ProtonCoreUIFoundations
import SwiftUI
import PDUIComponents
import UIKit
import PDLocalization

struct PhotoItemView<ViewModel: PhotoItemViewModelProtocol>: View {
    @Environment(\.window) var window: UIWindow?
    @ObservedObject var viewModel: ViewModel
    let accessibilityIndex: String
    let isPickingPhotos: Bool
    @State private var isAnimating = false

    private var accessibilityIdentifier: String {
        "PhotoItemView_\(accessibilityIndex)"
    }

    private var accessibilityBadgeIdentifier: String {
        "PhotoItemBadge_\(accessibilityIndex)"
    }

    init(
        viewModel: ViewModel,
        accessibilityIndex: String,
        isPickingPhotos: Bool = false
    ) {
        self.viewModel = viewModel
        self.accessibilityIndex = accessibilityIndex
        self.isPickingPhotos = isPickingPhotos
    }

    var body: some View {
        tappableContent
            .task(priority: .userInitiated) {
                // Add small delay. When the view gets hidden before the delay finishes, it means it has been
                // scrolled out of the screen. This should prevent excessive loading of resources when the user
                // is scrolling quickly through the items.
                try? await Task.sleep(nanoseconds: 1000 * 250) // 250 ms
                let isVisible = !Task.isCancelled
                updateViewModel(isVisible: isVisible)
            }
            // When task finishes after `onAppear`, we still need to use the normal `onDisappear`
            .onDisappear(perform: viewModel.onDisappear)
    }

    @MainActor
    private func updateViewModel(isVisible: Bool) {
        if isVisible {
            viewModel.onAppear()
        } else {
            viewModel.onDisappear()
        }
    }

    private var tappableContent: some View {
        content
            .contentShape(.interaction, Rectangle())
            .onTapGesture(perform: viewModel.didTap)
            .onLongPressGesture {
                if isPickingPhotos { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.didLongPress()
            }
            .contextMenu {
                if isPickingPhotos {
                    Button {
                        viewModel.didTap()
                    } label: {
                        HStack {
                            Text(Localization.general_select)
                            if viewModel.isSelected {
                                IconProvider.checkmark
                            }
                        }
                    }
                } else {
                    // Empty view can disable `contextMenu`
                    EmptyView()
                }

            } preview: {
                previewView()
            }

    }

    private var content: some View {
        ZStack {
            ColorProvider.BackgroundDeep
            viewModel.image.map(makeImage)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .overlay(alignment: .bottom) {
            viewModel.duration.map(makeDurationView)
        }
        .overlay(alignment: .top) {
            viewModel.badges.map { badges in
                makeBadgesView(badges: badges)
            }
        }
        .overlay(alignment: .topLeading) {
            selectionView
        }
        .overlay(alignment: .bottomTrailing) {
            viewModel.badges?.burstChildrenCount.map(makeBurstIcon)
        }
        .cornerRadius(4)
    }

    @ViewBuilder
    private var selectionView: some View {
        if viewModel.isSelecting {
            RoundedSelectionView(isSelected: viewModel.isSelected)
                .accessibilityIdentifier("\(accessibilityBadgeIdentifier).SelectionButton")
                .padding(11)
        }
    }
    
    @ViewBuilder
    private func makeBurstIcon(burstChildrenCount: Int?) -> some View {
        if let num = burstChildrenCount,
           let burstIcon = UIImage(named: "ic-burst") {
            IconBadgeView(
                text: "\(num + 1)",
                icon: burstIcon,
                accessibilityIDPrefix: "\(accessibilityBadgeIdentifier).burst"
            )
            .padding(.trailing, 6)
            .padding(.bottom, 6)
            .accessibilityLabel("\(accessibilityBadgeIdentifier).burst.badge")
        }
    }

    @ViewBuilder
    private func makeImage(with data: Data) -> some View {
        GeometryReader { geometry in
            Image(uiImage: UIImage(data: data) ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }

    private func makeDurationView(with duration: String) -> some View {
        HStack(spacing: 4) {
            Spacer()
            Text(duration)
                .font(.caption)
                .foregroundColor(ColorProvider.White)
            InternalIcon.playFilledBackground
        }
        .padding(EdgeInsets(top: 4, leading: 6, bottom: 6, trailing: 6))
        .background {
            InternalIcon.videoBackground
                .resizable(resizingMode: .tile)
        }
    }

    private func makeBadgesView(badges: PhotoItemViewModelBadges) -> some View {
        HStack(spacing: 4) {
            Spacer()
            if badges.isAvailableOffline {
                offlineAvailableView
            }
            if badges.isDownloading {
                downloadingView
            }
            badges.shareBadge.map(makeShareView)
            if badges.isFavorite {
                favoriteView
            }
        }
        .padding(EdgeInsets(top: 6, leading: 6, bottom: 4, trailing: 6))
        .background {
            InternalIcon.iconsBackground
                .resizable(resizingMode: .stretch)
        }
    }

    private var downloadingView: some View {
        InternalIcon.ellipseDotted
            .resizable()
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0.0))
            .animation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false), value: isAnimating)
            .overlay {
                InternalIcon.arrowDownWhite
                    .resizable()
                    .frame(width: 12, height: 12)
            }
            .onAppear { isAnimating = true }
            .onDisappear { isAnimating = false }
            .frame(width: 16, height: 16)
            .accessibilityIdentifier("\(accessibilityBadgeIdentifier).DownloadingIcon")
    }

    private var offlineAvailableView: some View {
        InternalIcon.arrowDownWhite
            .resizable()
            .frame(width: 16, height: 16)
            .accessibilityIdentifier("\(accessibilityBadgeIdentifier).AvailableOfflineIcon")
    }

    @ViewBuilder
    private func previewView() -> some View {
        if isPickingPhotos {
            let size = window?.screen.bounds.size ?? .init(width: 360, height: 550)
            let uiImage = UIImage(data: viewModel.image ?? Data()) ?? UIImage()
            let idealSize = viewModel.resizeToFit(imageSize: uiImage.size, in: size)
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(idealWidth: idealSize.width, idealHeight: idealSize.height)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func makeShareView(badge: PhotoItemShareBadge) -> some View {
        switch badge {
        case .link:
            IconProvider.link
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(ColorProvider.IconInverted)
                .accessibilityIdentifier("\(accessibilityBadgeIdentifier).ShareIcon")
        case .collaborative:
            InternalIcon.users
                .resizable()
                .foregroundColor(ColorProvider.White)
                .frame(width: 16, height: 16)
                .accessibilityIdentifier("\(accessibilityBadgeIdentifier).ShareIcon")
        }
    }

    private var favoriteView: some View {
        InternalIcon.heartFilled
            .resizable()
            .foregroundColor(ColorProvider.White)
            .frame(width: 16, height: 16)
            .accessibilityIdentifier("\(accessibilityBadgeIdentifier).FavoriteIcon")
    }
}

// SwiftUI calls init on some views in ForEach multiple times.
// This is prevented by moving content initialization to body, thus saving processing and memory.
struct PhotoItemWrapperView<ContentView: View>: View {
    private let content: () -> ContentView
    @State private var isVisible: Bool = false

    init(content: @escaping () -> ContentView) {
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
        }
    }
}
