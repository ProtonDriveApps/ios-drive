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

#if os(iOS)
import SwiftUI
import ProtonCoreUIFoundations

/// Note: we can use .refreshable on ScrollView directly. It has a better, more native interaction
public struct PullToRefreshView: View {
    @Binding private var isRefreshing: Bool
    @State private var showSpinner = false
    private var subtitle: String?
    private let coordinateSpaceName: String
    private let onRefresh: () -> Void

    public init(isRefreshing: Binding<Bool>, subtitle: String?, coordinateSpaceName: String, onRefresh: @escaping () -> Void) {
        self._isRefreshing = isRefreshing
        self.subtitle = subtitle
        self.coordinateSpaceName = coordinateSpaceName
        self.onRefresh = onRefresh
    }

    public var body: some View {
        HStack(alignment: .center) {
            if showSpinner {
                VStack {
                    Spacer(minLength: 15)

                    ProtonSpinner(size: .medium)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(ColorProvider.TextHint)
                            .padding()
                    }

                    Spacer(minLength: 10)
                }
                .frame(height: 80)
            }
        }
        .background(GeometryReader {
            Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self,
                                   value: $0.frame(in: .named(coordinateSpaceName)).origin.y)
        })
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { offset in
            if offset > 50 && !showSpinner {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showSpinner = true
            } else if offset < 2 && showSpinner && !isRefreshing {
                onRefresh()
            }
        }
        .onChange(of: isRefreshing) { newValue in
            if !newValue && showSpinner {
                showSpinner = false
            }
        }
    }
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    typealias Value = CGFloat

    static var defaultValue = CGFloat.zero

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

public struct VStackWithPullToRefresh<ContentView: View>: View {
    @Binding private var isRefreshing: Bool
    private let onRefresh: () -> Void
    private let content: () -> ContentView
    private let coordinateSpace = "VStackWithPullToRefreshCoordinateSpace"

    public init(isRefreshing: Binding<Bool>, onRefresh: @escaping () -> Void, content: @escaping () -> ContentView) {
        self._isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack {
                    PullToRefreshView(isRefreshing: _isRefreshing, subtitle: nil, coordinateSpaceName: coordinateSpace) {
                        onRefresh()
                    }
                    content()
                }
                .frame(minHeight: proxy.size.height)
            }
            .coordinateSpace(name: coordinateSpace)
        }
    }
}

#endif
