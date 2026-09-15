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

/// A single selectable subscription cycle row (e.g. "12 months  -20%        CHF 3.99 /month").
struct UpsellCycleOptionRow: View {
    let option: UpsellOfferContent.CycleOptionDisplay
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Text(option.cycleLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ColorProvider.White)

                    if let badge = option.discountBadge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ColorProvider.White.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text(option.priceLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ColorProvider.White)
                        
                        Text(option.monthLabel)
                            .font(.system(size: 12))
                            .foregroundColor(ColorProvider.White.opacity(0.7))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorProvider.Black.opacity(isSelected ? 0.4 : 0.2))
                )
                .overlay(border)
            }
            .buttonStyle(.plain)
        }
    }

    /// The selected row is outlined with the golden offer gradient; others get a plain separator.
    @ViewBuilder
    private var border: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 12)
                .stroke(LinearGradient.upsellGold, lineWidth: 2)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorProvider.SeparatorNorm, lineWidth: 1)
        }
    }

    /// Dark glyph shown inside the golden selection badge (kept fixed across light/dark themes).
    private var checkmarkColor: Color {
        Color(hex: "0C0C14")
    }
}
