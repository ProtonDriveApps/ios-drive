// Copyright (c) 2023 Proton AG
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

import ProtonCore_UIFoundations
import PDUIComponents
import SwiftUI

struct PhotosOnboardingRowView: View {
    private let row: PhotosOnboardingViewData.Row

    init(row: PhotosOnboardingViewData.Row) {
        self.row = row
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            iconView
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorProvider.TextNorm)
                Text(row.subtitle)
                    .font(.body)
                    .foregroundColor(ColorProvider.TextWeak)
            }
        }
    }

    private var iconView: some View {
        ZStack(alignment: .center) {
            color
            Image(uiImage: image)
                .renderingMode(.template)
                .foregroundColor(ColorProvider.IconAccent)
        }
        .cornerRadius(.extraHuge)
        .frame(width: 40, height: 40)
    }

    private var color: Color {
        Color(red: 0.427, green: 0.29, blue: 1, opacity: 0.2)
    }

    private var image: UIImage {
        switch row.icon {
        case .lock:
            return IconProvider.lock
        case .rotatingArrows:
            return IconProvider.arrowsRotate
        }
    }
}
