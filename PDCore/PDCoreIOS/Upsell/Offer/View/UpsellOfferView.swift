// Copyright (c) 2026 Proton AG
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

struct UpsellOfferView: View {
    @ObservedObject var viewModel: UpsellOfferViewModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient.upsellBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    illustration
                    content
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                buttonsSection
            }

            closeButton
        }
    }

    /// Full-width hero banner shown at the top of the upsell page.
    private var illustration: some View {
        Image("upsell-illustration", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
    }

    private var content: some View {
        VStack(spacing: 16) {
            Text(viewModel.content.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ColorProvider.White)
                .multilineTextAlignment(.center)

            Text(viewModel.content.subtitle)
                .font(.system(size: 15))
                .foregroundColor(ColorProvider.White)
                .multilineTextAlignment(.center)

            awardBadge

            reviewsBadge

            UpsellComparisonView(viewModel: viewModel)
                .padding(.top, 8)
        }
    }

    /// Laurel leaves flanking the PCMag "Best Privacy & Security" award.
    private var awardBadge: some View {
        HStack(spacing: 12) {
            leaf("leaf-left")
            VStack(spacing: 6) {
                Image("pc-mag", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                Text(viewModel.content.awardTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorProvider.White)
            }
            leaf("leaf-right")
        }
    }

    /// Rating pill: five stars and the locale-formatted review count.
    private var reviewsBadge: some View {
        HStack(spacing: 6) {
            stars
            Text(viewModel.content.reviewsBadge)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ColorProvider.White)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(ColorProvider.White.opacity(0.08)))
    }

    private var stars: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(LinearGradient.upsellGold)
            }
        }
    }

    /// A decorative laurel leaf flanking the award badge.
    private func leaf(_ name: String) -> some View {
        Image(name, bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(height: 44)
    }

    private var chooseSubscriptionSection: some View {
        VStack(spacing: 12) {
            Text(viewModel.content.chooseSubscriptionTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ColorProvider.White)

            ForEach(viewModel.content.cycleOptions) { option in
                UpsellCycleOptionRow(
                    option: option,
                    isSelected: viewModel.selectedIndex == option.index,
                    onTap: { viewModel.select(option.index) }
                )
            }
        }
    }

    private var buttonsSection: some View {
        VStack(spacing: 12) {
            chooseSubscriptionSection
                .padding(.top, 8)
            
            ZStack {
                BlueRectButton(
                    title: viewModel.isPurchasing ? "" : viewModel.content.ctaTitle,
                    foregroundColor: ColorProvider.Black,
                    backgroundColor: ColorProvider.White
                ) {
                    viewModel.purchase()
                }
                .clipShape(Capsule())
                if viewModel.isPurchasing {
                    ProtonSpinner(size: .small, style: .inverted)
                }
            }
            .disabled(viewModel.isPurchasing)

            Text(viewModel.footnote)
                .font(.system(size: 12))
                .foregroundColor(ColorProvider.White)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 8)
        .background(Color(hex: "452E8E").opacity(0.9))
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ColorProvider.White.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var closeButton: some View {
        Button(action: viewModel.close) {
            Image(uiImage: IconProvider.cross)
                .foregroundColor(ColorProvider.White)
                .padding(12)
        }
        .padding(.trailing, 8)
        .padding(.top, 8)
        .accessibilityLabel(viewModel.content.closeAccessibilityLabel)
    }
}
