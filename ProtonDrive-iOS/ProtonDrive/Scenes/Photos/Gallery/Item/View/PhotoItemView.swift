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

struct PhotoItemView<ViewModel: PhotoItemViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel
    private let accessibilityIdentifier: String
    @State private var isAnimating = false

    init(viewModel: ViewModel, accessibilityIndex: String) {
        self.viewModel = viewModel
        accessibilityIdentifier = "PhotoItemView_\(accessibilityIndex)"
    }

    var body: some View {
        content
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
            .contentShape(.interaction, Rectangle())
            .onTapGesture(perform: viewModel.didTap)
            .onLongPressGesture(perform: viewModel.didLongPress)
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
            if viewModel.shareBadge != nil || viewModel.isDownloading || viewModel.isAvailableOffline {
                statusView
            }
        }
        .overlay(alignment: .topLeading) {
            selectionView
        }
        .overlay(alignment: .bottomTrailing) {
            burstIcon
        }
    }

    @ViewBuilder
    private var selectionView: some View {
        if viewModel.isSelecting {
            RoundedSelectionView(isSelected: viewModel.isSelected)
                .accessibilityIdentifier("\(accessibilityIdentifier).SelectionButton")
                .padding(11)
        }
    }
    
    @ViewBuilder
    private var burstIcon: some View {
        if let num = viewModel.burstChildrenCount,
           let burstIcon = UIImage(named: "ic-burst") {
            IconBadgeView(
                text: "\(num + 1)",
                icon: burstIcon,
                accessibilityIDPrefix: "\(accessibilityIdentifier).burst"
            )
            .padding(.trailing, 6)
            .padding(.bottom, 6)
            .accessibilityLabel("\(accessibilityIdentifier).burst.badge")
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
            Image("ic-play-filled-background")
        }
        .padding(EdgeInsets(top: 4, leading: 6, bottom: 6, trailing: 6))
        .background {
            Image("video-background")
                .resizable(resizingMode: .tile)
        }
    }

    private var statusView: some View {
        HStack(spacing: 4) {
            Spacer()
            if viewModel.isAvailableOffline {
                offlineAvailableView
            }
            if viewModel.isDownloading {
                downloadingView
            }
            viewModel.shareBadge.map(makeShareView)
        }
        .padding(EdgeInsets(top: 6, leading: 6, bottom: 4, trailing: 6))
        .background {
            Image("icons-background")
                .resizable(resizingMode: .stretch)
        }
    }

    private var downloadingView: some View {
        Image("ellipse-dotted")
            .resizable()
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0.0))
            .animation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false), value: isAnimating)
            .overlay {
                Image("arrow-down-white")
                    .resizable()
                    .frame(width: 12, height: 12)
            }
            .onAppear { isAnimating = true }
            .onDisappear { isAnimating = false }
            .frame(width: 16, height: 16)
            .accessibilityIdentifier("\(accessibilityIdentifier).DownloadingIcon")
    }

    private var offlineAvailableView: some View {
        Image("ic-arrow-down-background")
            .resizable()
            .frame(width: 16, height: 16)
            .accessibilityIdentifier("\(accessibilityIdentifier).AvailableOfflineIcon")
    }

    @ViewBuilder
    private func makeShareView(badge: PhotoItemShareBadge) -> some View {
        switch badge {
        case .link:
            Image("ic-link-filled-background")
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityIdentifier("\(accessibilityIdentifier).ShareIcon")
        case .collaborative:
            Image("ic-shared-filled-background")
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityIdentifier("\(accessibilityIdentifier).ShareIcon")
        }
    }
}

// SwiftUI calls init on some views in ForEach multiple times.
// This is prevented by moving content initialization to body, thus saving processing and memory.
struct PhotoItemWrapperView<ContentView: View>: View {
    private let content: () -> ContentView

    init(content: @escaping () -> ContentView) {
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
        }
    }
}
