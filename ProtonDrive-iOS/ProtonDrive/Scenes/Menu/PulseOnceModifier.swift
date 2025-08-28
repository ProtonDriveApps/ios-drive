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

import SwiftUI

struct PulseOnceModifier: ViewModifier {
    let duration: Double
    let repeatCount: Int

    @State private var scale: CGFloat = 1.0
    @State private var pulseCount = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                animatePulse()
            }
    }

    private func animatePulse() {
        guard pulseCount < repeatCount else { return }

        withAnimation(.easeInOut(duration: duration)) {
            scale = 1.03
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation(.easeInOut(duration: duration)) {
                scale = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                pulseCount += 1
                animatePulse()
            }
        }
    }
}

extension View {
    func pulseOnce(duration: Double = 0.8, repeatCount: Int = 3) -> some View {
        modifier(PulseOnceModifier(duration: duration, repeatCount: repeatCount))
    }
}
