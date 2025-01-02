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

struct PhotosSettingsView<ViewModel: PhotosSettingsViewModelProtocol, DiagnosticView: View>: View {
    @ObservedObject private var viewModel: ViewModel
    @ViewBuilder var diagnosticsView: DiagnosticView
    @State private var isDiagnosticsPresented: Bool = false
    @State private var isPhotoFeatureAlertPresented = false

    init(viewModel: ViewModel, diagnosticsView: DiagnosticView) {
        self.viewModel = viewModel
        self.diagnosticsView = diagnosticsView
    }

    var body: some View {
        ZStack {
            content
                .flatNavigationBar(viewModel.backupTitle, leading: EmptyView(), trailing: EmptyView())
        }
        .background(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))
    }

    @ViewBuilder
    private var content: some View {
        VStack {
            VStack(spacing: 0) {
                backupEnabledRow
                    .separatedWithoutPadding()
                mobileDataRow
            }
            
            #if HAS_QA_FEATURES
            VStack(spacing: 0) {
                qaSectionTitleRow
                settingsImageRow
                    .separatedWithoutPadding()
                settingsVideoRow
                    .separatedWithoutPadding()
                HStack {
                    settingsDateRow
                    settingsDatePicker
                }
                .separatedWithoutPadding()
                diagnosticsRow
            }
            .padding(.vertical, 12)
            #endif
            
            Spacer()
//            if viewModel.shouldShowPhotoFeatureOption {
//                photoFeatureRow
//            }
        }
    }
    
    @ViewBuilder
    private var qaSectionTitleRow: some View {
        Text("QA SECTION")
            .font(.subheadline)
            .foregroundColor(ColorProvider.TextWeak)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
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
    private var settingsImageRow: some View {
        PhotosSettingsToggle(
            viewModel.imageTitle,
            isOn: .init(
                get: { viewModel.isImageEnabled },
                set: { value in viewModel.setImageEnabled(value) }
            ),
            isDisabled: viewModel.isEnabled || viewModel.isPhotoFeatureDisabled
        )
        .accessibilityIdentifier("PhotosBackupSettings.ImageSwitch")
    }
    
    @ViewBuilder
    private var settingsVideoRow: some View {
        PhotosSettingsToggle(
            viewModel.videoTitle,
            isOn: .init(
                get: { viewModel.isVideoEnabled },
                set: { value in viewModel.setVideoEnabled(value) }
            ),
            isDisabled: viewModel.isEnabled || viewModel.isPhotoFeatureDisabled
        )
        .accessibilityIdentifier("PhotosBackupSettings.VideoSwitch")
    }
    
    @ViewBuilder
    private var settingsDateRow: some View {
        PhotosSettingsToggle(
            viewModel.notOlderThanTitle,
            isOn: .init(
                get: { viewModel.isNotOlderThanEnabled },
                set: { value in viewModel.setIsNotOlderThanEnabled(value) }
            ),
            isDisabled: viewModel.isEnabled || viewModel.isPhotoFeatureDisabled
        )
        .accessibilityIdentifier("PhotosBackupSettings.DateSwitch")
    }
    
    @ViewBuilder
    private var settingsDatePicker: some View {
        DatePicker("", selection: .init(get: {
            viewModel.notOlderThan
        }, set: { value in
            viewModel.setNotOlderThan(value)
        }), displayedComponents: .date)
        .padding(.horizontal, 16)
        .datePickerStyle(.compact)
        .disabled(viewModel.isEnabled || viewModel.isPhotoFeatureDisabled)
        .disabled(!viewModel.isNotOlderThanEnabled)
    }

    @ViewBuilder
    private var diagnosticsRow: some View {
        Button(action: {
            isDiagnosticsPresented = true
        }, label: {
            Text(viewModel.diagnosticsTitle)
        })
        .foregroundColor(ColorProvider.BrandNorm)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("PhotosBackupSettings.OpenDiagnosticsButton")
        .sheet(isPresented: $isDiagnosticsPresented) {
            diagnosticsView
        }
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
//                viewModel.togglePhotoFeatureEnableStatus()
            })
        } message: {
            Text(viewModel.photoFeatureAlertMessage)
        }
    }

    struct PhotosSettingsToggle: View {
        var title: String
        var isOn: Binding<Bool>
        var isDisabled: Bool
        
        init(_ title: String, isOn: Binding<Bool>, isDisabled: Bool) {
            self.title = title
            self.isOn = isOn
            self.isDisabled = isDisabled
        }
        
        var body: some View {
            Toggle(title, isOn: isOn)
            .toggleStyle(SwitchToggleStyle(tint: ColorProvider.InteractionNorm))
            .font(.body)
            .foregroundColor(isDisabled ? ColorProvider.TextDisabled : ColorProvider.TextNorm)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .disabled(isDisabled)
        }
    }
}
