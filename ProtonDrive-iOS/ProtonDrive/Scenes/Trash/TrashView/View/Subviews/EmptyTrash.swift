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
import ProtonCore_UIFoundations

struct EmptyTrash: View {
    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            Image("empty_trash")
                .frame(width: imageLenght, height: imageLenght)

            Text("No files or folders in Trash")
                .font(.title)
                .bold()
                .padding(.vertical, 10)
                .padding(.horizontal, 50)
                .multilineTextAlignment(.center)
                .foregroundColor(ColorManager.TextNorm)

            Spacer()
            Spacer()
        }
        .transition(.opacity)
    }

    var imageLenght: CGFloat {
        switch UIDevice.current.orientation {
        case .portrait, .portraitUpsideDown:
            return UIScreen.main.bounds.width * 0.4
        default:
            return UIScreen.main.bounds.height * 0.25
        }
    }
}
