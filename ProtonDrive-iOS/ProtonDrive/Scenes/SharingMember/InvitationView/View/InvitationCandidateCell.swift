// Copyright (c) 2024 Proton AG
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
import SwiftUI
import ProtonCoreUIFoundations

struct InvitationCandidateCell: View {
    
    let candidate: ContactQueryResult
    @Binding var isSelected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if candidate.isGroup {
                Image(uiImage: IconProvider.usersFilled)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 16, height: 16)
                    .foregroundColor(isSelected ? Color.white : ColorProvider.IconNorm)
                    .padding(.leading, 8)
            }
            Text(candidate.displayName)
                .foregroundColor(textColor)
                .font(.system(size: 17))
                .padding(.leading, candidate.isGroup ? 0 : 8)
                .padding(.trailing, candidate.isDuplicated ? 4 : 8)
                .padding(.vertical, 4)
            if candidate.isDuplicated {
                duplicatedIcon
                    .padding(.trailing, 8)
            }
        }
        .background(backgroundColor)
        .cornerRadius(.small)
        .allowsHitTesting(false)
    }
    
    private var backgroundColor: some View {
        if isSelected {
            Color(ColorProvider.BrandNorm)
        } else if candidate.isError {
            Color(ColorProvider.NotificationError)
        } else {
            Color(ColorProvider.BackgroundSecondary)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            Color.white
        } else if candidate.isError {
            Color(ColorProvider.TextInverted)
        } else {
            Color(ColorProvider.TextNorm)
        }
    }
    
    private var duplicatedIcon: some View {
        AvatarView(
            config: .init(
                avatarSize: .init(width: 16, height: 16),
                content: .right(IconProvider.infoCircleFilled),
                backgroundColor: .clear,
                foregroundColor: ColorProvider.NotificationError,
                iconSize: .init(width: 16, height: 16)
            )
        )
    }
}
