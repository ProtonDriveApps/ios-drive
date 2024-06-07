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

public struct RectangleToast<Content: View>: View {
    public enum Orientation { case vertical, horizontal }
    
    let message: String
    var foregroundColor: Color
    var backgroundColor: Color
    var button: Content
    var orientation: Orientation

    public init(
        message: String,
        orientation: Orientation = .horizontal,
        foregroundColor: Color = .white,
        backgroundColor: Color,
        @ViewBuilder button: () -> Content
    ) {
        self.message = message
        self.orientation = orientation
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.button = button()
    }
    
    public var body: some View {
        VStack {
            HStack(alignment: .center) {
                Text(self.message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .foregroundColor(self.foregroundColor)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .accessibility(identifier: "RectangleToast.ErrorToast")
                Spacer()
                
                if self.orientation == .horizontal {
                    self.button
                    .padding(.leading, 4)
                    .padding(.top, 5)
                }
            }
            
            HStack(alignment: .center) {
                if self.orientation == .vertical {
                    self.button
                }
            }
        }
        .background(
            self.backgroundColor.cornerRadius(.medium)
        )
    }
}

struct ErrorToast_Previews: PreviewProvider {
    static let errors: PassthroughSubject<String?, Never> = .init()
    
    static var previews: some View {
        Group {
            RectangleToast(message: "Someting went wrong: email or password or both.", backgroundColor: Color.NotificationError) {
                RoundButtonView(imageName: "times", action: { })
                    .foregroundColor(.green)
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
