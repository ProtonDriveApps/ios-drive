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

struct StretchModifier: ViewModifier {
    let containerFrame: CGRect

    func body(content: Content) -> some View {
        GeometryReader { reader in
            VStack {
                Spacer()
                content
            }
            .frame(minHeight: heightFor(reader), alignment: .top)
        }
    }

    func heightFor(_ reader: GeometryProxy) -> CGFloat {
        let height = reader.size.height
        let maxY = reader.frame(in: .global).maxY - containerFrame.minY
        let deltaY = (containerFrame.height - maxY)
        return height + max(0, deltaY)
    }
}
