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

struct ViewVisibilityDetector: View {
    let onVisible: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: ViewVisibleKey.self, value: proxy.frame(in: .global).minY)
        }
        .frame(height: 0)
    }
}

private struct ViewVisibleKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func onVisible(threshold: CGFloat = 50, perform: @escaping () -> Void) -> some View {
        self.background(
            ViewVisibilityDetector(onVisible: perform)
        )
        .onPreferenceChange(ViewVisibleKey.self) { minY in
            let screenHeight = UIScreen.main.bounds.height
            if minY >= 0 && minY < screenHeight - threshold {
                perform()
            }
        }
    }
}
