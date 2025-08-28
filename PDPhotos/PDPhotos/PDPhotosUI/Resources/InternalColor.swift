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

import Foundation
import SwiftUI

enum InternalColor {
    static var videoDurationBackground: Color {
        Color(hex: "706d6b")
    }

    static var buttonBackgroundNorm: Color {
        .init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "292733") : UIColor(hex: "f8f8f8")
        })
    }

    static var shareButtonForeground: Color {
        .init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "ecfdf5") : UIColor(hex: "059669")
        })
    }

    static var shareButtonBackground: Color {
        .init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "059669") : UIColor(hex: "ecfdf5")
        })
    }

    static var disabledSelectionBackground: Color {
        Color(hex: "b9d6cd")
    }

    static var selectionCrossIconColor: Color {
        Color(hex: "0c0c14")
    }

    static var pomegranate: Color {
        Color(hex: "CC2D4F")
    }

    static var albumGridBorder: Color {
        .init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "292733") : UIColor(hex: "ffffff")
        })
    }

    static var coverPlaceholderColor: Color {
        .init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "3f3d4a") : UIColor(hex: "8f8f93")
        })
    }

    static var greenIconColor: Color {
        .init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "3CBB3A") : UIColor(hex: "02C6A1")
        })

    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (red, green, blue, alpha) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (red, green, blue, alpha) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (red, green, blue, alpha) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (red, green, blue, alpha) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 100
        )
    }
}
