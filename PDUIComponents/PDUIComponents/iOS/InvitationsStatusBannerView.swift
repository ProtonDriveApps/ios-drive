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

#if os(iOS)
import SwiftUI
import ProtonCoreUIFoundations

public struct InvitationsStatusBannerView: View {
    private let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Image(uiImage: IconProvider.usersFilled)
                    .font(.system(size: 24))
                    .foregroundColor(ColorProvider.IconNorm)
                    .padding(10)
                    .background(ColorProvider.BackgroundSecondary)
                    .clipShape(RoundedRectangle(cornerSize: CGSize(width: 4, height: 4)))

                Circle()
                    .fill(ColorProvider.NotificationError)
                    .frame(width: 8, height: 8)
                    .offset(x: 16, y: -16)
                    .shadow(color: ColorProvider.NotificationError.opacity(0.6), radius: 10, x: 0, y: 0)
            }

            VStack(alignment: .leading) {
                Text(text)
                    .foregroundColor(ColorProvider.TextNorm)
            }

            Spacer()

            Image(uiImage: IconProvider.chevronRight)
                .font(.system(size: 16))
                .foregroundColor(ColorProvider.IconNorm)
        }
        .background(ColorProvider.BackgroundNorm)
    }
}
#endif
