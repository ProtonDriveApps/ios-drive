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
import ProtonCoreUIFoundations

public struct RoundButtonView: View {
    public init(imageName: String, action: @escaping () -> Void) {
        self.imageName = imageName
        self.action = action
    }
    
    var imageName: String
    var action: () -> Void
    
    public var body: some View {
        Button(action: action, label: {
            Image(imageName)
            .resizable()
            .frame(width: 24, height: 24)
            .accentColor(Color.IconNorm)
        })
        .frame(width: 44, height: 72, alignment: .trailing)
        .accessibility(identifier: "RoundButtonView.Button.Plus_Button")
    }
}

struct RoundButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RoundButtonView(imageName: "plus", action: { })
                .background(ColorProvider.BackgroundNorm)
            
            RoundButtonView(imageName: "plus", action: { })
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.dark)
            
            RoundButtonView(imageName: "plus", action: { })
                .background(ColorProvider.BackgroundNorm)
            
            RoundButtonView(imageName: "plus", action: { })
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.dark)
            
        }
        .frame(width: 150, height: 150, alignment: .center)
        .previewLayout(.sizeThatFits)
        
    }
}
