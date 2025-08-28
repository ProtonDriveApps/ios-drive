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
import PDUIComponents

struct ActionButton: View {
    private var title: String
    private var icon: Image
    private var foregroundColor: Color
    private var backgroundColor: Color
    private var action: () -> Void
    @Binding private var isLoading: Bool

    init(
        title: String,
        icon: Image,
        foregroundColor: Color,
        backgroundColor: Color,
        isLoading: Binding<Bool>? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self._isLoading = isLoading ?? .init(get: { false }, set: { _ in })
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 4) {
                if isLoading {
                    ProtonSpinner(size: .custom(24))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                } else {
                    icon
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(foregroundColor)
                        .padding(.leading, 16)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(foregroundColor)
                        .padding(.trailing, 16)
                        .padding(.vertical, 10)
                }
            }
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
