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

private struct OffsetPreferenceKey: PreferenceKey {

    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { }
}

public struct OffsettableScrollView<T: View>: View {
    let axes: Axis.Set
    let showsIndicator: Bool
    let onOffsetChanged: (CGPoint) -> Void
    let onRefresh: (() -> Void)?
    let content: (ScrollViewProxy) -> T

    public init(
        axes: Axis.Set = .vertical,
        showsIndicator: Bool = true,
        onOffsetChanged: @escaping (CGPoint) -> Void = { _ in },
        onRefresh: (() -> Void)? = nil,
        content: @escaping (ScrollViewProxy) -> T
    ) {
        self.axes = axes
        self.showsIndicator = showsIndicator
        self.onOffsetChanged = onOffsetChanged
        self.onRefresh = onRefresh
        self.content = content
    }

    public var body: some View {
        if let onRefresh = onRefresh {
            scrollView
                .refreshable {
                    onRefresh()
                }
        } else {
            scrollView
        }
    }

    private var scrollView: some View {
        ScrollView(axes, showsIndicators: showsIndicator) {
            ScrollViewReader { scrollViewProxy in
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: OffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("ScrollViewOrigin")).origin
                    )
                }
                .frame(width: 0, height: 0)
                content(scrollViewProxy)
            }
        }
        .coordinateSpace(name: "ScrollViewOrigin")
        .onPreferenceChange(OffsetPreferenceKey.self, perform: onOffsetChanged)
    }
}
