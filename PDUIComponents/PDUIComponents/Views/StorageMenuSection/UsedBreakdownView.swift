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

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct UsedBreakdownView: View {
    @Binding var usedBreakdown: String
    @Binding var isShortOnStorage: Bool
    
    #if canImport(UIKit)
    let uiFont: UIFont = .preferredFont(forTextStyle: .footnote)
    #elseif canImport(AppKit)
    let uiFont: NSFont = .preferredFont(forTextStyle: .footnote)
    #endif
    
    let font: Font = .footnote
    
    var firstWordWidth: CGFloat {
        // TODO: separator word should be localized
        guard let firstWord = self.usedBreakdown.components(separatedBy: "of").first else {
            return 0
        }
        
        let fontAttributes = [NSAttributedString.Key.font: uiFont]
        let size = String(firstWord).size(withAttributes: fontAttributes)
        return size.width
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Text(self.usedBreakdown)
                .font(self.font)
                .foregroundColor(.white)
            
            ColorProvider.TextHint
            .blendMode(.darken)
            .padding(.leading, self.firstWordWidth)
             
            Group {
                if self.isShortOnStorage {
                    Color.NotificationError
                } else {
                    Color.BrandNorm
                }
            }
            .blendMode(.darken)
            .frame(width: self.firstWordWidth)
        }
        .fixedSize()
    }
}

struct UsedBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            UsedBreakdownView(usedBreakdown: .constant("500 Mb of 3.0 Gb"),
                              isShortOnStorage: .constant(false))
            
            UsedBreakdownView(usedBreakdown: .constant("2.9 Gb of 3.0 Gb"),
                              isShortOnStorage: .constant(true))
        }
        .background(Color.IconNorm)
        .previewLayout(.sizeThatFits)
    }
}
