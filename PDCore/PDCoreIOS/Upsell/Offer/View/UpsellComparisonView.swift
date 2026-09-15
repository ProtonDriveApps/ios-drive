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

/// Free-vs-paid comparison table. The paid column is visually emphasized.
struct UpsellComparisonView: View {
    @ObservedObject var viewModel: UpsellOfferViewModel

    private let columnWidth: CGFloat = 72
    /// The emphasized (paid) column is wider so its header badge can sit centered with side margins.
    private let paidColumnWidth: CGFloat = 108

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            ForEach(viewModel.content.comparisonRows) { row in
                rowSeparator
                comparisonRow(row)
            }
        }
        .background(alignment: .trailing) { emphasizedColumnHighlight }
    }

    /// Hairline shown between comparison rows (the system `Divider` is invisible on the dark background).
    private var rowSeparator: some View {
        Rectangle()
            .fill(ColorProvider.White.opacity(0.12))
            .frame(height: 1)
    }

    /// Outlines the emphasized (paid) column with the same gold border and fill as the selected cycle row.
    private var emphasizedColumnHighlight: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(ColorProvider.White.opacity(0.08))
            .frame(width: paidColumnWidth)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Spacer()
            columnTitle(viewModel.content.freeColumnTitle, width: columnWidth)
            columnTitle(viewModel.content.paidColumnTitle, width: paidColumnWidth, emphasized: true)
        }
        .padding(.vertical, 12)
    }

    private func comparisonRow(_ row: UpsellOfferContent.ComparisonRow) -> some View {
        HStack(spacing: 0) {
            Text(row.label)
                .font(.system(size: 14))
                .foregroundColor(ColorProvider.White)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            cell(row.free, emphasized: false)
            cell(row.paid, emphasized: true)
        }
        .padding(.vertical, 12)
    }

    private func columnTitle(_ title: String, width: CGFloat, emphasized: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(ColorProvider.White)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay {
                if emphasized {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LinearGradient.upsellGold, lineWidth: 2)
                }
            }
            .frame(width: width)
    }

    @ViewBuilder
    private func cell(_ cell: UpsellOfferContent.ComparisonRow.Cell, emphasized: Bool) -> some View {
        Group {
            switch cell {
            case .text(let value):
                if emphasized {
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundStyle(LinearGradient.upsellGold)
                } else {
                    Text(value)
                        .font(.system(size: 14))
                        .foregroundColor(ColorProvider.White)
                }
            case .available(let isAvailable):
                if isAvailable {
                    Image(uiImage: IconProvider.checkmark)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(ColorProvider.Black)
                        .frame(width: 24, height: 24)
                        .background(ColorProvider.White)
                        .clipShape(Circle())
                } else {
                    Text("-")
                        .foregroundColor(ColorProvider.White)
                }
            }
        }
        .frame(width: emphasized ? paidColumnWidth : columnWidth)
    }
}
