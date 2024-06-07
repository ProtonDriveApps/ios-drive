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

struct CloseButtonView: View {    
    var closeAction: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                RoundButtonView(imageName: "times", action: closeAction)
                
                Spacer()
            }

            Spacer()
        }
    }
}

struct CloseButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CloseButtonView(closeAction: { })
                .background(ColorProvider.BackgroundNorm)
            
            CloseButtonView(closeAction: { })
                .background(ColorProvider.BackgroundNorm)
                .colorScheme(.dark)
        }
        .frame(width: 150, height: 150, alignment: .center)
        .previewLayout(.sizeThatFits)
    }
}

public extension View {
    func closable(_ closeAction: @escaping () -> Void) -> some View {
        ModifiedContent(content: self, modifier: CloseButtonModifier(closeAction: closeAction))
    }
}

struct CloseButtonModifier: ViewModifier {
    var closeAction: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            CloseButtonView(closeAction: closeAction)
        }
    }
}
