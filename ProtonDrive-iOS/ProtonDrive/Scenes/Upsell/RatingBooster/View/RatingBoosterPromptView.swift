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
import PDUIComponents
import ProtonCoreUIFoundations

struct RatingBoosterPromptView: View {
    @ObservedObject var viewModel: RatingBoosterPromptViewModel

    var body: some View {
        SheetContainer(contentView: content)
    }

    private var content: some View {
        VStack(spacing: 0) {
            Text(viewModel.viewData.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ColorProvider.TextNorm)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("RatingBoosterPromptView.title")

            Text(viewModel.viewData.message)
                .font(.system(size: 15))
                .foregroundStyle(ColorProvider.TextWeak)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .lineSpacing(4)
                .accessibilityIdentifier("RatingBoosterPromptView.message")

            primaryButton
                .padding(.top, 24)
                .padding(.horizontal, 40)
                .accessibilityIdentifier("RatingBoosterPromptView.primaryButton")

            LightButton(
                title: viewModel.viewData.secondaryButtonTitle,
                color: ColorProvider.BrandNorm,
                font: .body,
                action: viewModel.secondaryButtonTapped
            )
            .padding(.top, 16)
            .accessibilityIdentifier("RatingBoosterPromptView.secondaryButton")
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var primaryButton: some View {
        Button(action: viewModel.primaryButtonTapped) {
            HStack(spacing: 8) {
                if viewModel.viewData.hasHeart {
                    IconProvider.heart
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                Text(viewModel.viewData.primaryButtonTitle)
                    .font(.body)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(ColorProvider.BrandNorm)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
