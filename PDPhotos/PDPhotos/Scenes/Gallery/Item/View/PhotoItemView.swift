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
    let disablesLongPress: Bool
    @State private var isAnimating = false

    private let selectionIconSize: CGFloat = 18
    private let selectionViewSize: CGFloat = 21
    private let selectionPadding: CGFloat = 11
    
    private let badgeIconSize: CGFloat = 16
    private let downloadingArrowSize: CGFloat = 12

    private let badgeSpacing: CGFloat = 4
    private let badgeInsets = EdgeInsets(top: 6, leading: 6, bottom: 4, trailing: 6)

    private let overlayMinScale: CGFloat = 0.55

    private let burstMinCellWidth: CGFloat = PhotosGridLayoutFactory.defaultItemWidth / 2

    private let selectedTintOpacity: CGFloat = 0.30

    private var accessibilityIdentifier: String {
        "PhotoItemView_\(accessibilityIndex)"
    }

    private var accessibilityBadgeIdentifier: String {
        "PhotoItemBadge_\(accessibilityIndex)"
    }

    init(
        viewModel: ViewModel,
        accessibilityIndex: String,
        isPickingPhotos: Bool = false,
        disablesLongPress: Bool = false
    ) {
        self.viewModel = viewModel
        self.accessibilityIndex = accessibilityIndex
        self.isPickingPhotos = isPickingPhotos
        self.disablesLongPress = disablesLongPress
    }

    var body: some View {
        tappableContent
            .task(priority: .userInitiated) {
                // Add small delay. When the view gets hidden before the delay finishes, it means it has been
                // scrolled out of the screen. This should prevent excessive loading of resources when the user
                // is scrolling quickly through the items.
                try? await Task.sleep(for: .milliseconds(25)) // 25 ms
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
            .modifier(ConditionalLongPressModifier(
                enabled: !disablesLongPress && !isPickingPhotos,
                action: viewModel.didLongPress
            ))
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
            if viewModel.isSelected {
                ColorProvider.White.opacity(selectedTintOpacity)
            }
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
            GeometryReader { proxy in
                let scale = overlayScale(forCellWidth: proxy.size.width)
                RoundedSelectionView(
                    isSelected: viewModel.isSelected,
                    iconSize: selectionIconSize * scale,
                    viewSize: selectionViewSize * scale
                )
                .accessibilityIdentifier("\(accessibilityBadgeIdentifier).SelectionButton")
                .padding(selectionPadding * scale)
            }
        }
    }

    private func overlayScale(forCellWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return 1 }
        let scale = width / PhotosGridLayoutFactory.defaultItemWidth
        return min(max(scale, overlayMinScale), 1)
    }

    private func scaledEdgeInsets(_ insets: EdgeInsets, by scale: CGFloat) -> EdgeInsets {
        EdgeInsets(
            top: insets.top * scale,
            leading: insets.leading * scale,
            bottom: insets.bottom * scale,
            trailing: insets.trailing * scale
        )
    }

    @ViewBuilder
    private func makeBurstIcon(burstChildrenCount: Int?) -> some View {
        if let num = burstChildrenCount,
           let burstIcon = UIImage(named: "ic-burst") {
            GeometryReader { proxy in
                if proxy.size.width >= burstMinCellWidth {
                    IconBadgeView(
                        text: "\(num + 1)",
                        icon: burstIcon,
                        accessibilityIDPrefix: "\(accessibilityBadgeIdentifier).burst"
                    )
                    .padding(.trailing, 6)
                    .padding(.bottom, 6)
                    .accessibilityLabel("\(accessibilityBadgeIdentifier).burst.badge")
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomTrailing)
                }
            }
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
        GeometryReader { proxy in
            // Prioritize duration over icon rendering for videos when zooming out
            ViewThatFits(in: .horizontal) {
                durationContent(duration: duration, showsIcon: true)
                durationContent(duration: duration, showsIcon: false)
                durationContent(duration: nil, showsIcon: false)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background {
                InternalIcon.videoBackground
                    .resizable(resizingMode: .tile)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
    }

    private func durationContent(duration: String?, showsIcon: Bool) -> some View {
        HStack(spacing: 4) {
            if let duration {
                Text(duration)
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundColor(ColorProvider.White)
                    .lineLimit(1)
                    .fixedSize()
            }
            if showsIcon {
                InternalIcon.playFilledBackground
            }
        }
        .padding(EdgeInsets(top: 4, leading: 6, bottom: 6, trailing: 6))
    }

    private func makeBadgesView(badges: PhotoItemViewModelBadges) -> some View {
        GeometryReader { proxy in
            let scale = overlayScale(forCellWidth: proxy.size.width)
            let showsSecondaryBadges = badgesFit(badges, cellWidth: proxy.size.width, scale: scale)
            
            if showsSecondaryBadges || badges.isFavorite {
                HStack(spacing: badgeSpacing * scale) {
                    if showsSecondaryBadges {
                        if badges.isAvailableOffline {
                            offlineAvailableView(scale: scale)
                        }
                        if badges.isDownloading {
                            downloadingView(scale: scale)
                        }
                        badges.shareBadge.map { makeShareView(badge: $0, scale: scale) }
                    }
                    if badges.isFavorite {
                        favoriteView(scale: scale)
                    }
                }
                .padding(scaledEdgeInsets(badgeInsets, by: scale))
                .frame(width: proxy.size.width, alignment: .trailing)
                .background {
                    InternalIcon.iconsBackground
                        .resizable(resizingMode: .stretch)
                }
            }
        }
    }

    private func badgesFit(_ badges: PhotoItemViewModelBadges, cellWidth: CGFloat, scale: CGFloat) -> Bool {
        var count = 0
        if badges.isAvailableOffline { count += 1 }
        if badges.isDownloading { count += 1 }
        if badges.shareBadge != nil { count += 1 }
        if badges.isFavorite { count += 1 }
        guard count > 1 else { return true }

        let icon = badgeIconSize * scale
        let spacing = badgeSpacing * scale
        let available = cellWidth - (badgeInsets.leading + badgeInsets.trailing) * scale
        return CGFloat(count) * icon + CGFloat(count - 1) * spacing <= available
    }

    private func downloadingView(scale: CGFloat) -> some View {
        InternalIcon.ellipseDotted
            .resizable()
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0.0))
            .animation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false), value: isAnimating)
            .overlay {
                InternalIcon.arrowDownWhite
                    .resizable()
                    .frame(width: downloadingArrowSize * scale, height: downloadingArrowSize * scale)
            }
            .onAppear { isAnimating = true }
            .onDisappear { isAnimating = false }
            .frame(width: badgeIconSize * scale, height: badgeIconSize * scale)
            .accessibilityIdentifier("\(accessibilityBadgeIdentifier).DownloadingIcon")
    }

    private func offlineAvailableView(scale: CGFloat) -> some View {
        InternalIcon.arrowDownWhite
            .resizable()
            .frame(width: badgeIconSize * scale, height: badgeIconSize * scale)
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
    private func makeShareView(badge: PhotoItemShareBadge, scale: CGFloat) -> some View {
        switch badge {
        case .link:
            IconProvider.link
                .resizable()
                .frame(width: badgeIconSize * scale, height: badgeIconSize * scale)
                .foregroundStyle(ColorProvider.IconInverted)
                .accessibilityIdentifier("\(accessibilityBadgeIdentifier).ShareIcon")
        case .collaborative:
            InternalIcon.users
                .resizable()
                .foregroundColor(ColorProvider.White)
                .frame(width: badgeIconSize * scale, height: badgeIconSize * scale)
                .accessibilityIdentifier("\(accessibilityBadgeIdentifier).ShareIcon")
        }
    }

    private func favoriteView(scale: CGFloat) -> some View {
        InternalIcon.heartFilled
            .resizable()
            .foregroundColor(ColorProvider.White)
            .frame(width: badgeIconSize * scale, height: badgeIconSize * scale)
            .accessibilityIdentifier("\(accessibilityBadgeIdentifier).FavoriteIcon")
    }
}

/// Applies `onLongPressGesture` only when `enabled` — lets the collection-view
/// grid own the long-press (for drag-select) while the SwiftUI grid keeps its own.
private struct ConditionalLongPressModifier: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.onLongPressGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            }
        } else {
            content
        }
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
