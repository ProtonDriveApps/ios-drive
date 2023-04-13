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

import SwiftUI

public struct GradientButton: View {
    @Environment(\.isEnabled) var isEnabled
    private let title: String
    private let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(GradientButtonStyle())
    }
}

private struct GradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Self.Configuration) -> some View {
        HStack {
            configuration.label
                .font(.body)
                .foregroundColor(Color.SidebarTextNorm)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(stroke)
    }

    private var stroke: some View {
        RoundedRectangle(cornerRadius: CornerRadius.huge.rawValue)
            .stroke(linearGradient, lineWidth: 1)
    }

    private var linearGradient: some ShapeStyle {
        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private var colors: [Color] {
        [
            Color(red: 110.0 / 255.0, green: 75.0 / 255.0, blue: 1),
            Color(red: 253.0 / 255.0, green: 75.0 / 255.0, blue: 175.0 / 255.0),
            Color(red: 34.0 / 255.0, green: 216.0 / 255.0, blue: 1),
        ]
    }
}
