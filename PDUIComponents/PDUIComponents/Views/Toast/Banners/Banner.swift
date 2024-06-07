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
import Combine
import ProtonCoreUIFoundations

public struct Banner: View {
    let message: String
    let foregroundColor: Color
    let backgroundColor: Color

    public init(
        message: String,
        foregroundColor: Color = Color.white,
        backgroundColor: Color = Color.NotificationError
    ) {
        self.message = message
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Spacer()

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .foregroundColor(foregroundColor)
                .padding(.vertical, 14)
                .padding(.horizontal, 14)

            Spacer()
        }
        .background(
            backgroundColor
                .cornerRadius(6)
        )
    }
}

struct Banner_Previews: PreviewProvider {
    static let errors: PassthroughSubject<String?, Never> = .init()

    static var previews: some View {
        Banner(message: "Someting went wrong")
        .previewLayout(.sizeThatFits)
    }
}
