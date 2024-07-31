// Copyright (c) 2024 Proton AG
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
import PDUIComponents
import ProtonCoreUIFoundations

struct PhotoUpsellView: View {
    @ObservedObject var viewModel: PhotoUpsellViewModel
    
    var body: some View {
        VStack {
            Image("photo-upsell")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.horizontal, 24)
                .padding(.top, 100)
                .padding(.bottom, 30)
                .accessibilityIdentifier("PhotoUpsellView.imageIdentifier")
            
            Text("Never run out of storage")
                .foregroundColor(ColorProvider.TextNorm)
                .font(.system(size: 22))
                .fontWeight(.bold)
                .padding(.bottom, 8)
                .accessibilityIdentifier("PhotoUpsellView.titleIdentifier")

            Text("Upgrade now and keep all your memories encrypted and safe.")
                .foregroundColor(ColorProvider.TextWeak)
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("PhotoUpsellView.textIdentifier")

            Spacer()
            
            BlueRectButton(title: "Get more storage", action: { viewModel.upgradeButtonDidTap() })
                .cornerRadius(8)
                .padding(24)
                .accessibilityIdentifier("PhotoUpsellView.upgradeButton")
            
            LightButton(
                title: "Not now",
                color: ColorProvider.BrandNorm,
                font: .body,
                action: { viewModel.notNowButtonDidTap() }
            )
            .padding(.bottom, 24)
            .accessibilityIdentifier("PhotoUpsellView.skipButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorProvider.BackgroundSecondary)
    }

}
