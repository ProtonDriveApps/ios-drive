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
import PDLocalization
import ProtonCoreUIFoundations

struct StorageBonusChecklistView: View {
    @ObservedObject var viewModel: StorageBonusChecklistViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image("storage-bonus-promo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)

                Text(Localization.storage_bonus_checklist_title)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text(Localization.storage_bonus_checklist_subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    ForEach(StorageBonusStep.allCases, id: \.self) { step in
                        StorageBonusChecklistRow(
                            step: step,
                            isCompleted: viewModel.isStepCompleted(step)
                        )
                    }
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 16)
        }
        .background(ColorProvider.BackgroundNorm)
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }
}

private struct StorageBonusChecklistRow: View {

    let step: StorageBonusStep
    let isCompleted: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCompleted ? ColorProvider.NotificationSuccess.opacity(0.1) : ColorProvider.BackgroundSecondary)
                    .frame(width: 36, height: 36)

                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(isCompleted ? ColorProvider.NotificationSuccess : ColorProvider.BrandNorm)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(step.attributedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    var icon: Image {
        isCompleted ? IconProvider.checkmark : step.icon
    }
}
