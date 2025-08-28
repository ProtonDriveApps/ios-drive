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

struct PhotosSettingsQAView<ViewModel: PhotosSettingsQAViewModelProtocol, DiagnosticView: View>: View {
    @ObservedObject var viewModel: ViewModel
    @ViewBuilder var diagnosticsView: DiagnosticView
    @State private var isDiagnosticsPresented = false

    init(viewModel: ViewModel, diagnosticsView: DiagnosticView) {
        self.viewModel = viewModel
        self.diagnosticsView = diagnosticsView
    }

    var body: some View {
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
            isTagsAnalysisDisabledRow
                .separatedWithoutPadding()
            isEXIFUploadingDisabledRow
                .separatedWithoutPadding()
            diagnosticsRow
        }
        .padding(.vertical, 12)
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
    private var isTagsAnalysisDisabledRow: some View {
        PhotosSettingsToggle(
            viewModel.isTagsAnalysisDisabledTitle,
            subtitle: viewModel.tagsAnalysisDescription,
            isOn: .init(
                get: { viewModel.isTagsAnalysisDisabled },
                set: { value in viewModel.setIsTagsAnalysisDisabled(value) }
            ),
            isDisabled: viewModel.isEnabled || viewModel.isPhotoFeatureDisabled
        )
        .accessibilityIdentifier("PhotosBackupSettings.VideoSwitch")
    }

    @ViewBuilder
    private var isEXIFUploadingDisabledRow: some View {
        PhotosSettingsToggle(
            viewModel.isEXIFUploadingDisabledTitle,
            subtitle: viewModel.exifUploadingDescription,
            isOn: .init(
                get: { viewModel.isEXIFUploadingDisabled },
                set: { value in viewModel.setIsEXIFUploadingDisabled(value) }
            ),
            isDisabled: viewModel.isEnabled || viewModel.isPhotoFeatureDisabled
        )
        .accessibilityIdentifier("PhotosBackupSettings.exifUploading.switch")
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
}
