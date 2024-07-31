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

struct OneDollarUpsellView: View {
    @ObservedObject var model: OneDollarUpsellViewModel
    
    var body: some View {
        VStack {
            Image("upsell-drive-lite")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(.horizontal, 24)
                .padding(.top, 100)
                .padding(.bottom, 30)
                .accessibilityIdentifier("OneDollarUpsellView.imageIdentifier")
            
            Text("More storage for only \(model.localPriceLabel)")
                .foregroundColor(ColorProvider.TextNorm)
                .font(.system(size: 22))
                .fontWeight(.bold)
                .padding(.bottom, 8)
                .accessibilityIdentifier("OneDollarUpsellView.titleIdentifier")
                .animation(.smooth, value: model.localPriceLabel)

            Text("When you need a little more storage, but not a lot. Introducing Drive Lite, featuring 20 GB storage for only \(model.localPriceLabel) a month.")
                .foregroundColor(ColorProvider.TextWeak)
                .font(.system(size: 17))
                .lineLimit(nil)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("OneDollarUpsellView.textIdentifier")
                .animation(.smooth, value: model.localPriceLabel)

            Spacer()
            
            BlueRectButton(title: "Get Drive Lite", action: model.onButtonTapped)
            .cornerRadius(8)
            .padding(24)
            .accessibilityIdentifier("OneDollarUpsellView.nextButton")
            
            LightButton(title: "Not now", color: ColorProvider.BrandNorm, font: .body, action: model.onSkipButtonTapped)
            .padding(.bottom, 24)
            .accessibilityIdentifier("OneDollarUpsellView.skipButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorProvider.BackgroundSecondary)
        .onAppear(perform: model.onAppear)
        .task { await model.fetchLocalPrice() }
    }

}