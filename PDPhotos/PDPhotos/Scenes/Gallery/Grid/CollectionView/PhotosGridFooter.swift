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

import SwiftUI
import ProtonCoreUIFoundations
import PDUIComponents

struct PhotosGridFooter: View {
    @ObservedObject var viewModel: PhotosGridViewModel

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.paginationStatus {
            case .finished:
                EmptyView()
            case .loading:
                ProtonSpinner(size: .small)
                    .padding(.bottom)
            case .error:
                Text(viewModel.footerError)
                    .tint(ColorProvider.NotificationError)
                    .padding(.bottom)
            }

            endToEndEncrypted
        }
        .padding(.vertical, 16)
    }

    private var endToEndEncrypted: some View {
        HStack(alignment: .center, spacing: 6) {
            Spacer()
            IconProvider.lockCheckFilled
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundColor(ColorProvider.IconWeak)
            Text(viewModel.footer)
                .font(.caption)
                .foregroundColor(ColorProvider.TextWeak)
            Spacer()
        }
        .padding(.bottom, 16)
    }
}
