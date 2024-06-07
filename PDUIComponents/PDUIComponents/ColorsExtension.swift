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

public extension Color {
    static var NotificationError: Color {
        #if canImport(UIKit)
        ColorProvider.NotificationError
        #else
        ColorProvider.SignalDanger
        #endif
    }

    static var NotificationWarning: Color {
        #if canImport(UIKit)
        ColorProvider.NotificationWarning
        #else
        ColorProvider.SignalDanger
        #endif
    }

    static var BrandNorm: Color {
        #if canImport(UIKit)
        ColorProvider.BrandNorm
        #else
        Color.black
        #endif
    }

    static var IconNorm: Color {
        #if canImport(UIKit)
        ColorProvider.IconNorm
        #else
        Color.black
        #endif
    }

    static var FloatyBackground: Color {
        #if canImport(UIKit)
        ColorProvider.FloatyBackground
        #else
        Color.black
        #endif
    }

    static var NotificationSuccess: Color {
        #if canImport(UIKit)
        ColorProvider.NotificationSuccess
        #else
        ColorProvider.SignalSuccess
        #endif
    }

    static var BlenderNorm: Color {
        #if canImport(UIKit)
        ColorProvider.BlenderNorm
        #else
        Color.black
        #endif
    }

    static var BackgroundSecondary: Color {
        #if canImport(UIKit)
        ColorProvider.BackgroundSecondary
        #else
        Color.black
        #endif
    }

    static var IconWeak: Color {
        #if canImport(UIKit)
        ColorProvider.IconWeak
        #else
        Color.black
        #endif
    }

    static var SeparatorNorm: Color {
        #if canImport(UIKit)
        ColorProvider.SeparatorNorm
        #else
        Color.black
        #endif
    }

    static var TextNorm: Color {
        #if canImport(UIKit)
        ColorProvider.TextNorm
        #else
        Color.black
        #endif
    }

    static var SidebarTextNorm: Color {
        #if canImport(UIKit)
        ColorProvider.SidebarTextNorm
        #else
        Color.black
        #endif
    }

    static var SidebarSeparator: Color {
        #if canImport(UIKit)
        ColorProvider.SidebarSeparator
        #else
        Color.black
        #endif
    }

    static var SidebarTextWeak: Color {
        #if canImport(UIKit)
        ColorProvider.SidebarTextWeak
        #else
        Color.black
        #endif
    }
}
