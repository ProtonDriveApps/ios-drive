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
import PDCoreIOS
import ProtonCoreUIFoundations

struct ShareMemberRow: View {
    let userList: [InvitationInfoWrapper]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(userList.prefix(3)) { list in
                userCell(user: list)
                    .padding(.leading, -3)
            }
            if userList.count > 3 {
                moreCell()
                    .padding(.leading, -3)
            }
        }
    }

    @ViewBuilder
    func userCell(user: InvitationInfoWrapper) -> some View {
        let color = color(id: user.id)
        Text(user.name.prefix(1).uppercased())
            .font(.system(size: 11))
            .foregroundStyle(color.1)
            .frame(width: 20, height: 20)
            .background(color.0)
            .cornerRadius(10)
            .overlay {
                Circle()
                    .stroke(ColorProvider.BackgroundNorm, lineWidth: 3)
                    .frame(width: 23, height: 23)
            }
    }

    @ViewBuilder
    func moreCell() -> some View {
        let foreground = Color(hex: "0c0c14")
        let background = Color(hex: "e4e7e4")

        IconProvider.threeDotsHorizontal
            .resizable()
            .frame(width: 12, height: 12)
            .foregroundStyle(foreground)
            .frame(width: 20, height: 20)
            .background(background)
            .cornerRadius(10)
            .overlay {
                Circle()
                    .stroke(ColorProvider.BackgroundNorm, lineWidth: 3)
                    .frame(width: 23, height: 23)
            }
    }

    func color(id: String) -> (Color, Color) {
        // (background, foreground)
        let colors: [(Color, Color)] = [
            (Color(hex: "bfd5f3"), Color(hex: "071355")),
            (Color(hex: "c0e3f2"), Color(hex: "093d53")),
            (Color(hex: "ecc6ea"), Color(hex: "4b1148")),
            (Color(hex: "f5cea2"), Color(hex: "5c3100")),
            (Color(hex: "e0d1d1"), Color(hex: "392b22")),
            (Color(hex: "ede9c4"), Color(hex: "554e07")),
            (Color(hex: "babaf7"), Color(hex: "00005c")),
            (Color(hex: "c9e9c9"), Color(hex: "164616")),
            (Color(hex: "ffcccc"), Color(hex: "660000")),
            (Color(hex: "e6ccff"), Color(hex: "600060")),
        ]
        let index = abs(id.hash) % colors.count
        return colors[index]
    }
}
