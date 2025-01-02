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

import SwiftUI
import ProtonCoreUIFoundations
import ProtonCoreUtilities

#if os(iOS)
public struct AvatarViewConfig {
    let content: Either<String, UIImage>
    let cornerRadius: CornerRadius
    let backgroundColor: Color
    let foregroundColor: Color
    let avatarSize: CGSize
    let fontSize: CGFloat
    let iconSize: CGSize
    
    public init(
        avatarSize: CGSize = .init(width: 32, height: 32),
        content: Either<String, UIImage>,
        cornerRadius: CornerRadius = .huge,
        backgroundColor: Color = ColorProvider.Shade40,
        foregroundColor: Color? = nil,
        fontSize: CGFloat = 14,
        iconSize: CGSize = .init(width: 16, height: 16)
    ) {
        self.avatarSize = avatarSize
        self.content = content
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        if let foregroundColor {
            self.foregroundColor = foregroundColor
        } else {
            switch content {
            case .left:
                self.foregroundColor = ColorProvider.TextNorm
            case .right:
                self.foregroundColor = ColorProvider.IconNorm
            }
        }
        self.fontSize = fontSize
        self.iconSize = iconSize
    }
}

public struct AvatarView: View {
    private let config: AvatarViewConfig
    
    public init(config: AvatarViewConfig) {
        self.config = config
    }
    
    public var body: some View {
        switch config.content {
        case .left(let text):
            textView(text: text)
        case .right(let icon):
            iconView(image: icon)
        }
    }
    
    private func iconView(image: UIImage) -> some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(config.foregroundColor)
                .frame(width: config.iconSize.width, height: config.iconSize.height)
        }
        .frame(width: config.avatarSize.width, height: config.avatarSize.height)
        .background(config.backgroundColor)
        .cornerRadius(config.cornerRadius)
    }
    
    @ViewBuilder
    private func textView(text: String) -> some View {
        let initiative = text.isEmpty ? "?" : "\(String(text.uppercased().first ?? "?"))"
        
        Text(initiative)
            .font(.system(size: config.fontSize))
            .frame(width: config.avatarSize.width, height: config.avatarSize.height)
            .background(config.backgroundColor)
            .foregroundColor(config.foregroundColor)
            .cornerRadius(config.cornerRadius)
    }
}
#endif
