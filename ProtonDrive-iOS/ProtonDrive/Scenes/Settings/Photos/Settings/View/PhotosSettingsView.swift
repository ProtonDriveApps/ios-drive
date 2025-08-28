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

import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct PhotosSettingsView<ViewModel: PhotosSettingsViewModelProtocol, QASettingsView: View>: View {
    @ObservedObject private var viewModel: ViewModel
    @ViewBuilder var qaSettingsView: QASettingsView
    @State private var isDiagnosticsPresented: Bool = false
    @State private var isPhotoFeatureAlertPresented = false

    init(viewModel: ViewModel, qaSettingsView: QASettingsView) {
        self.viewModel = viewModel
        self.qaSettingsView = qaSettingsView
    }

    var body: some View {
        ZStack {
            content
                .flatNavigationBar(
                    viewModel.backupTitle,
                    isRoot: false,
                    leading: EmptyView(),
                    trailing: EmptyView()
                )
        }
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
    }

    @ViewBuilder
    private var content: some View {
        VStack {
            VStack(spacing: 0) {
                viewModel.topBanner.map {
                    NotificationBanner(message: $0, style: .transparent, padding: .vertical)
                }
                backupEnabledRow
                    .separatedWithoutPadding()
                mobileDataRow
            }

            qaSettingsView

            Spacer()

            if viewModel.shouldShowPhotoFeatureOption {
                photoFeatureRow
            }
        }
    }

    @ViewBuilder
    private var backupEnabledRow: some View {
        PhotosSettingsToggle(
            viewModel.backupTitle,
            isOn: .init(
                get: { viewModel.isEnabled },
                set: { value in viewModel.setEnabled(value) }
            ),
            isDisabled: viewModel.isPhotoFeatureDisabled
        )
        .accessibilityIdentifier("PhotosBackupSettings.Switch")
    }

    @ViewBuilder
    private var mobileDataRow: some View {
        PhotosSettingsToggle(
            viewModel.mobileDataTitle,
            isOn: .init(
                get: { viewModel.isMobileDataEnabled },
                set: { value in viewModel.setMobileDataEnabled(value) }
            ),
            isDisabled: viewModel.isPhotoFeatureDisabled
        )
        .accessibilityIdentifier("PhotosBackupSettings.MobileDataSwitch")
    }

    @ViewBuilder
    private var photoFeatureRow: some View {
        VStack(spacing: 0) {
            Rectangle()
                .foregroundStyle(Color.clear)
                .frame(height: 0.1)
                .separatedWithoutPadding()

            photoFeatureButton
                .separatedWithoutPadding()

            Text(viewModel.photoFeatureExplanation)
                .foregroundStyle(ColorProvider.TextHint)
                .font(.system(size: 13))
                .padding(.top, 10)
                .padding(.bottom, 44)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("PhotosBackupSettings.PhotoFeatureExplanation")
        }
    }

    @ViewBuilder
    private var photoFeatureButton: some View {
        Button {
            isPhotoFeatureAlertPresented = true
        } label: {
            Text(viewModel.photoFeatureTitle)
            if viewModel.isPhotoFeatureToggleInProgress {
                ProtonSpinner(size: .small)
            }
        }
        .foregroundColor(viewModel.isPhotoFeatureDisabled ? ColorProvider.BrandNorm : ColorProvider.NotificationError)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityIdentifier(viewModel.photoFeatureAccessibilityID)
        .alert(
            viewModel.photoFeatureTitle,
            isPresented: $isPhotoFeatureAlertPresented
        ) {
            Button(viewModel.photoFeatureAlertCancelTitle, action: { })
            Button(viewModel.photoFeatureAlertButtonTitle, action: {
                Task {
                    await viewModel.togglePhotoFeatureEnableStatus()
                }
            })
            .disabled(viewModel.isPhotoFeatureToggleInProgress)
        } message: {
            Text(viewModel.photoFeatureAlertMessage)
        }
    }
}
struct PhotosSettingsToggle: View {
    var title: String
    let subtitle: String?
    var isOn: Binding<Bool>
    var isDisabled: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>, isDisabled: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.isOn = isOn
        self.isDisabled = isDisabled
    }

    var body: some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.body)
                subtitle.map {
                    Text($0)
                        .font(.caption)
                }
            }
            .multilineTextAlignment(.leading)
        }
        .toggleStyle(SwitchToggleStyle(tint: ColorProvider.InteractionNorm))
        .foregroundColor(isDisabled ? ColorProvider.TextDisabled : ColorProvider.TextNorm)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .disabled(isDisabled)
    }
}
