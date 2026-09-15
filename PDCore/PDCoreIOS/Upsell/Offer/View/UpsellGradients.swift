// Copyright (c) 2026 Proton AG
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

import PDUIComponents
import SwiftUI

extension LinearGradient {
    /// The golden offer gradient (`linear-gradient(220.14deg, …)`) from the design — approximated as a
    /// top-trailing → bottom-leading sweep. Shared by the selected cycle border, its checkmark badge and
    /// the rating stars.
    static let upsellGold = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: "FDEBA9"), location: 0.0625),
            .init(color: Color(hex: "FFE083"), location: 0.2846),
            .init(color: Color(hex: "DBA42A"), location: 0.5067),
            .init(color: Color(hex: "B2781A"), location: 0.7289),
            .init(color: Color(hex: "FDEBA9"), location: 0.951)
        ]),
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
    
    /// Page background — `linear-gradient(177.17deg, #1D121D, #6D4AFF)` from the design, applied as a vertical sweep.
    static let upsellBackground = LinearGradient(
        colors: [Color(hex: "1D121D"), Color(hex: "6D4AFF")],
        startPoint: .top,
        endPoint: .bottom
    )
}
