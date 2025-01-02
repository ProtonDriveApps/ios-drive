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

#if os(iOS)
import SwiftUI
import ProtonCoreUIFoundations

public struct IconBadgeView: View {
    let text: String
    let icon: UIImage
    let prefix: String
    
    public init(text: String, icon: UIImage, accessibilityIDPrefix: String) {
        self.text = text
        self.icon = icon
        self.prefix = accessibilityIDPrefix
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.system(size: 11).bold())
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("\(prefix).badge.\(text)")
            
            AvatarView(
                config: .init(
                    avatarSize: .init(width: 16, height: 16),
                    content: .right(icon),
                    cornerRadius: .circled,
                    backgroundColor: ColorProvider.IconHint,
                    foregroundColor: .white,
                    iconSize: .init(width: 12, height: 12)
                )
            )
        }
        .background(Color(hex: "706D6B46").opacity(0.7))
        .cornerRadius(.huge)
    }
}
#endif
