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
        VStack {
            NotificationBanner(message: Localization.setting_debug_mode_instructions_body, style: .inverted, padding: .vertical)

            VStack {

                HStack {
                    Text(Localization.setting_debug_mode)
                        .font(.headline)

                    Spacer()
                    
                    Toggle("", isOn: $viewModel.isDebugModeEnabled)
                        .tint(ColorProvider.BrandNorm)
                        .labelsHidden()
                }
                .padding(.bottom)

                Spacer()
            }
            .padding()
        }
        .background(ColorProvider.BackgroundNorm)
    }
}
