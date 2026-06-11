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

import PDCore
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct DuplicationActionView: View {
    @ObservedObject var viewModel: DuplicationActionViewModel

    var body: some View {
        SheetContainer(
            contentView: content,
            isBackgroundTapDismissEnabled: false,
            isDragDismissEnabled: false
        )
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let item = viewModel.currentItem {
                itemContent(item)
                    .id(item.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.default, value: viewModel.currentItem?.id)
        .clipped()
    }

    private func itemContent(_ item: DuplicationItem) -> some View {
        VStack(spacing: 16) {
            headerView
            actionRows
            applyToAllRow
            continueButton
            cancelButton
        }
        .padding(.bottom, 8)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(viewModel.title)
                .modifier(ResizableTextModifier(
                    alignment: .center,
                    font: .title3,
                    fontWeight: .bold,
                    textColor: ColorProvider.TextNorm
                ))
                .accessibilityIdentifier("DuplicationActionView.title")

            Text(viewModel.subtitle)
                .modifier(ResizableTextModifier(
                    alignment: .center,
                    font: .subheadline,
                    textColor: ColorProvider.TextWeak
                ))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("DuplicationActionView.subtitle.\(viewModel.currentItem?.filename ?? "unknownFilename")")
        }
    }

    // MARK: - Radio Rows

    private var actionRows: some View {
        VStack(spacing: 8) {
            ForEach(DuplicateUploadAction.allCases, id: \.self) { action in
                actionRow(action)
            }
        }
    }

    private func actionRow(_ action: DuplicateUploadAction) -> some View {
        let isSelected = viewModel.selectedAction == action
        return Button {
            viewModel.selectedAction = action
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? ColorProvider.BrandNorm : ColorProvider.TextWeak)
                    .font(.system(size: 22))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .modifier(ResizableTextModifier(
                            font: .callout,
                            fontWeight: .semibold,
                            textColor: ColorProvider.TextNorm
                        ))

                    Text(action.description)
                        .modifier(ResizableTextModifier(
                            font: .footnote,
                            textColor: ColorProvider.TextWeak
                        ))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(12)
            .background(ColorProvider.BackgroundSecondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }

    // MARK: - Checkbox

    private var applyToAllRow: some View {
        Button {
            viewModel.applyToAll.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.applyToAll ? "checkmark.square.fill" : "square")
                    .foregroundColor(viewModel.applyToAll ? ColorProvider.BrandNorm : ColorProvider.TextWeak)
                    .font(.system(size: 22))

                Text(viewModel.applyToAllTitle)
                    .modifier(ResizableTextModifier(
                        font: .callout,
                        textColor: ColorProvider.TextNorm
                    ))

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityIdentifier("DuplicationActionView.button.applyToAll")
    }

    // MARK: - Buttons

    private var continueButton: some View {
        Button(action: viewModel.continueAction) {
            VStack {
                Text(viewModel.continueTitle)
                    .modifier(ResizableTextModifier(
                        alignment: .center,
                        font: .body,
                        textColor: .white
                    ))
                    .padding(.vertical, 10)
            }
            .background(ColorProvider.BrandNorm)
            .cornerRadius(.huge)
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("DuplicationActionView.button.continue")
    }

    private var cancelButton: some View {
        Button(action: viewModel.cancelAllUploads) {
            Text(viewModel.cancelTitle)
                .modifier(ResizableTextModifier(
                    alignment: .center,
                    font: .callout,
                    textColor: ColorProvider.BrandNorm
                ))
        }
        .accessibilityIdentifier("DuplicationActionView.button.cancel.all.uploads")
    }
}
