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

import Foundation
import SwiftUI
import PDLocalization
import ProtonCoreUIFoundations
import PDUIComponents

struct DebugModeSettingsView: View {
    @ObservedObject var viewModel: DebugModeSettingsViewModel

    var body: some View {
        List {
            Section {
                Toggle(Localization.setting_debug_mode, isOn: $viewModel.isDebugModeEnabled)
                    .tint(ColorProvider.BrandNorm)
            } footer: {
                sectionFooter(Localization.setting_debug_mode_instructions_body)
            }

            Section {
                diagnosticsCell(title: "Storage Diagnostics", action: viewModel.didTapDiagnostics)
                diagnosticsCell(title: "Photo Backup Diagnostics", action: viewModel.didTapPhotoDiagnostics)
            } header: {
                sectionHeader("Diagnostics")
            }

            experimentalFeaturesView()

            if let version = viewModel.sdkLibraryVersion {
                Text("SDK library v\(version)")
                    .font(.footnote)
                    .foregroundStyle(ColorProvider.TextWeak)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ColorProvider.BackgroundNorm)
    }

    @ViewBuilder
    private func experimentalFeaturesView() -> some View {
        if !viewModel.experimentalFeatures.isEmpty {
            Section {
                ForEach(
                    viewModel.experimentalFeatures.keys.sorted { $0.rawValue < $1.rawValue },
                    id: \.self
                ) { key in
                    Toggle(
                        key.rawValue,
                        isOn: .init(
                            get: { viewModel.experimentalFeatures[key] ?? false },
                            set: { viewModel.toggleExperimentalFeature(key, newValue: $0) }
                        )
                    )
                    .tint(ColorProvider.BrandNorm)
                }
            } header: {
                sectionHeader("Experimental features")
            } footer: {
                sectionFooter("The app will restart when you change an experimental feature.")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .textCase(nil)
    }

    private func sectionFooter(_ text: String) -> some View {
        NotificationBanner(
            message: text,
            style: .normal,
            padding: .vertical
        )
        .padding(.horizontal, -16)
    }

    func diagnosticsCell(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(ColorProvider.TextNorm)

                Spacer()

                Image(uiImage: IconProvider.arrowRight)
                    .foregroundStyle(ColorProvider.IconHint)
            }
        }
        .buttonStyle(.plain)
    }
}
