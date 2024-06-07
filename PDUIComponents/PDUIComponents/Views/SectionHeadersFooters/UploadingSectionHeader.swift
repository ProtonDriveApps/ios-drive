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

public struct UploadingSectionHeader: View {
    public init(title: String) {
        self.title = title
    }
    
    var title: String
    
    public var body: some View {
        Text(self.title)
            .font(.footnote)
            .foregroundColor(ColorProvider.TextWeak)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 23)
            .padding(.horizontal, 16)
            .background(ColorProvider.BackgroundNorm)
    }
}

struct UploadingSectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        UploadingSectionHeader(title: "Uploading")
    }
}
