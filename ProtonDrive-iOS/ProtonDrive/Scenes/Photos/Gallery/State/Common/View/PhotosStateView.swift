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

struct PhotosStateView<ViewModel: PhotosStateViewModelProtocol, TitleView: View>: View {
    @ObservedObject private var viewModel: ViewModel
    private let title: ([PhotosStateTitle]) -> TitleView
    private let additionalView: () -> AnyView?

    init(viewModel: ViewModel, title: @escaping ([PhotosStateTitle]) -> TitleView, additionalView: @escaping () -> AnyView?) {
        self.viewModel = viewModel
        self.title = title
        self.additionalView = additionalView
    }

    var body: some View {
        if let data = viewModel.viewData {
            makeBody(with: data)
        } else {
            EmptyView()
        }
    }

    private func makeBody(with data: PhotosStateViewData) -> some View {
        ZStack(alignment: .center) {
            Color.BackgroundSecondary
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    title(data.titles)
                        .accessibilityIdentifier(makeAccessibilityIdentifier(for: data.type))
                    Spacer(minLength: 0)
                    if let button = data.button {
                        makeButton(with: button) {
                            viewModel.didTapButton(button: button)
                        }
                    } else {
                        data.rightText.map(makeRightText)
                    }
                }
                data.progress.map(makeProgress)
                    .animation(.default, value: viewModel.viewData)
                additionalView()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
        }
        .frame(minHeight: 46)
        .fixedSize(horizontal: false, vertical: true)
        .cornerRadius(.huge)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
    
    private func makeButton(with button: PhotosStateButton, action: @escaping () -> Void) -> some View {
        Button(action: action,
           label: {
            Text(button.title)
                .foregroundColor(ColorProvider.TextAccent)
                .font(.body.bold())
                .frame(minWidth: 54, minHeight: 48)
        })
        .accessibility(identifier: makeAccessibilityIdentifier(for: button))
        .buttonStyle(PlainButtonStyle())
    }

    private func makeRightText(with text: String) -> some View {
        Text(text)
            .foregroundColor(ColorProvider.TextAccent)
            .font(.body.bold())
    }

    private func makeProgress(with progress: Float) -> some View {
        GeometryReader { geometry in
            ColorProvider.InteractionWeak
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    ColorProvider.InteractionNorm
                        .frame(width: geometry.size.width * CGFloat(progress))
                }
                .cornerRadius(.medium)
        }
        .accessibilityHidden(false)
        .accessibilityIdentifier(makeAccessibilityIdentifier(with: "ProgressBar"))
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    private func makeAccessibilityIdentifier(for button: PhotosStateButton) -> String {
        switch button {
        case .retry:
            return makeAccessibilityIdentifier(with: "RetryButton")
        case .turnOn:
            return makeAccessibilityIdentifier(with: "TurnOnButton")
        case .settings:
            return makeAccessibilityIdentifier(with: "SettingsButton")
        case .useCellular:
            return makeAccessibilityIdentifier(with: "UseCellularButton")
        }
    }

    private func makeAccessibilityIdentifier(for state: PhotosStateViewData.StateType) -> String {
        switch state {
        case .inProgress:
            return makeAccessibilityIdentifier(with: "InProgressBanner")
        case .complete:
            return makeAccessibilityIdentifier(with: "CompleteBanner")
        case .completeWithFailures:
            return makeAccessibilityIdentifier(with: "CompleteWithFailuresBanner")
        case .disabled:
            return makeAccessibilityIdentifier(with: "DisabledBanner")
        case .restrictedPermissions:
            return makeAccessibilityIdentifier(with: "RestrictedPermissionsBanner")
        case .noConnection:
            return makeAccessibilityIdentifier(with: "NoConnectionBanner")
        case .noWifi:
            return makeAccessibilityIdentifier(with: "NoWifiBanner")
        case .storageConstrained:
            return makeAccessibilityIdentifier(with: "StorageConstrainedBanner")
        case .featureFlag:
            return makeAccessibilityIdentifier(with: "FeatureFlagBanner")
        case .libraryLoading:
            return makeAccessibilityIdentifier(with: "LibraryLoadingBanner")
        }
    }

    private func makeAccessibilityIdentifier(with suffix: String) -> String {
        "PhotosStateView." + suffix
    }
}
