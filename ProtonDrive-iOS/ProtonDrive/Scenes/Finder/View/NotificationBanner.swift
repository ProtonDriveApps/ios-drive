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
import SwiftUI

/// Use the one from UIFoundations when implemented
struct NotificationBanner: View {
    let message: String
    let closeBlock: () -> Void
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(ColorProvider.TextInverted)
                    .padding(12)
                    .accessibility(identifier: "NotificationBanner.text")
                Spacer()
                
                Button(action: closeBlock) {
                    IconProvider.crossBig
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(ColorProvider.IconInverted)
                }
                .padding(.trailing, 20)
                .accessibility(identifier: "NotificationBanner.close")
            }
        }
        .background(
            ColorProvider.NotificationNorm.cornerRadius(.huge)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
