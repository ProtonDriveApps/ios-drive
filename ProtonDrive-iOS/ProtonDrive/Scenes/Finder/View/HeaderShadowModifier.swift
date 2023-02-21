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

import Foundation
import SwiftUI
import ProtonCore_UIFoundations

/// Adds shadow to header view of a section.
/// Used with ``GridOrList`` modified by ``HeaderScrollSignal`` and ``HeaderScrollObserver``.
struct HeaderShadowModifier: ViewModifier {
    @Binding var visible: Bool
    
    func body(content: Content) -> some View {
        content
        .background( // visible background of the frame
            ColorProvider.BackgroundNorm
                .frame(maxWidth: .infinity)
        )
        .background( // base for shadow calculation
            ColorProvider.BackgroundNorm
                .shadow(color: visible ? ColorProvider.Shade40 : Color.clear, radius: 4)
                .clipShape(Rectangle().offset(.init(x: 0, y: 8)))
        )
    }
}

/// Observes preference of scroll offset of ``HeaderScrollSignal``
struct HeaderScrollObserver<Key: PreferenceKey>: ViewModifier where Key.Value == CGFloat {
    @Binding var visible: Bool
    
    func body(content: Content) -> some View {
        content
        .onPreferenceChange(Key.self) { offset in
            visible = offset < 0
        }
    }
}

/// Signals scroll offset via preference for ``HeaderScrollObserver`` to observe
struct HeaderScrollSignal<Key: PreferenceKey>: ViewModifier where Key.Value == CGFloat {
    var coordinateSpace: String
    
    func body(content: Content) -> some View {
        ZStack {
            GeometryReader { proxy in
                let offset = proxy.frame(in: .named(coordinateSpace)).minY
                Color.clear.preference(key: Key.self, value: offset)
            }
            
            content
                .animation(nil) // probably prevents shattering glitch in sticky header on iOS 14
        }
    }
}

/// Transient (uploading) section header of ``GridOrList``
struct GridOrListSection1OffsetPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

/// Permanent nodes section header of ``GridOrList``
struct GridOrListSection2OffsetPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}
