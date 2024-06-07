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

public struct PasswordProgressBar: View {
    static let height: CGFloat = 6
    static let cornerRadius: CGFloat = 0.5 * height

    let progress: Double
    let color: Color

    public init(progress: Double, color: Color) {
        self.progress = progress
        self.color = color
    }

    public var body: some View {
        VStack {
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.BackgroundSecondary)
                    .frame(height: Self.height)
                    .cornerRadius(Self.cornerRadius)

                GeometryReader { geometry in
                    Rectangle()
                        .foregroundColor(color)
                        .frame(width: progress.clamped * geometry.size.width)
                        .cornerRadius(Self.cornerRadius)
                }
                .frame(height: Self.height )
            }
        }
    }
}

private extension Double {
    var clamped: CGFloat {
        CGFloat(self.clamp(low: 0, high: 1))
    }
}

extension Comparable {
    func clamp(low: Self, high: Self) -> Self {
        if self > high {
            return high
        } else if self < low {
            return low
        }
        return self
    }
}
