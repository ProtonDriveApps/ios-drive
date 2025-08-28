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
import ProtonCoreUIFoundations
import PDUIComponents

struct DetailSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: ComputerDetailViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.detailItems.indices, id: \.self) { index in
                        HStack {
                            Text(viewModel.detailItems[index].label)
                                .foregroundColor(ColorProvider.TextNorm)
                            Spacer()
                            Text(viewModel.detailItems[index].value)
                                .foregroundColor(ColorProvider.TextWeak)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .background(ColorProvider.BackgroundNorm)
            .navigationBarTitle(viewModel.sheetTitle, displayMode: .inline)
            .navigationBarItems(
                leading: SimpleCloseButtonView(dismiss: { dismiss() })
            )
        }
    }
}
