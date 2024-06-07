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

struct PhotosStateTitlesView<ViewModel: PhotosStateTitlesViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel
    @State private var isAnimating = false

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        viewModel.item.map(makeContent)
    }

    private func makeContent(with item: PhotosStateTitle) -> some View {
        HStack(spacing: 8) {
            makeIcon(with: item.icon)
                .accessibilityIdentifier("PhotosStateTitlesView.icon")
            Text(item.title)
                .foregroundColor(ColorProvider.TextNorm)
                .font(.body)
        }
        .animation(isAnimating ? .default : nil, value: viewModel.item)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }

    @ViewBuilder
    private func makeIcon(with icon: PhotosStateTitle.Icon) -> some View {
        switch icon {
        case .lock:
            IconProvider.lock
                .renderingMode(.template)
                .foregroundColor(ColorProvider.NotificationSuccess)
        case .progress:
            RotatingArrowsView()
        case .complete:
            IconProvider.checkmarkCircle
                .renderingMode(.template)
                .foregroundColor(ColorProvider.NotificationSuccess)
        case .completeWithFailures:
            IconProvider.exclamationCircle
                .renderingMode(.template)
                .foregroundColor(ColorProvider.NotificationWarning)
        case .failure:
            IconProvider.exclamationCircle
                .renderingMode(.template)
                .foregroundColor(ColorProvider.NotificationError)
        case .disabled:
            Image("ic-cloud-slash")
                .renderingMode(.template)
                .foregroundColor(ColorProvider.IconWeak)
        case .noConnection:
            Image("ic-no-connection")
                .renderingMode(.template)
                .foregroundColor(ColorProvider.NotificationError)
        }
    }
}

private struct RotatingArrowsView: View {
    @State private var isRotating = false

    var body: some View {
        IconProvider.arrowsRotate
            .renderingMode(.template)
            .foregroundColor(ColorProvider.IconAccent)
            .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
            .animation(isRotating ? Animation.linear(duration: 2).repeatForever(autoreverses: false) : Animation.default, value: isRotating)
            .onAppear {
                withAnimation {
                    isRotating = true
                }
            }
            .onDisappear {
                isRotating = false
            }
    }
}
