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

public struct SheetHeaderView: View {
    public init(title: String, subtitle: String? = nil, dismiss: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.dismiss = dismiss
    }
    
    var title: String
    var subtitle: String?
    var dismiss: () -> Void
    
    public var body: some View {
        ZStack(alignment: .leading) {

            SimpleCloseButtonView(dismiss: dismiss)
                .padding(.leading, 8)
            
            HStack {
                Spacer()
                
                VStack(alignment: .center) {
                    Text(self.title)
                        .foregroundColor(ColorProvider.TextNorm)
                        .font(.body)
                        .bold()
                        .lineLimit(1)
                    
                    if self.subtitle != nil {
                        Text(self.subtitle!)
                            .foregroundColor(ColorProvider.TextWeak)
                            .font(.subheadline)
                    }
                }
                
                Spacer()
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 50)
        }
        .padding(.vertical, -8)
        .padding(.horizontal, 8)
        .animation(nil)
    }
}

struct SheetHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SheetHeaderView(title: "Title", dismiss: { })
            
            SheetHeaderView(title: "Very long title that should take two lines", subtitle: "Subtitle", dismiss: { })
        }
        .previewLayout(.sizeThatFits).padding(.vertical, 50)
    }
}
