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

import PDCore
import SwiftUI

struct GridScrollerView<ViewModel: GridScrollerViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    private let dimensions = GridScrollerDimensions()
    private let coordinateSpace = "GridScrollerViewSpace"
    @State private var isVisible: Bool = false
    @State private var height: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let screenHeight = proxy.size.height
             HStack {
                 Spacer(minLength: 0)
                 switch viewModel.mode {
                 case .items:
                     makeItems(screenHeight: screenHeight)
                         .frame(minWidth: 100)
                         .contentShape(Capsule())
                         .background(tappableAreaBackgroundColor)
                 case .scroller:
                     VStack(alignment: .trailing, spacing: 0) {
                         Spacer()
                             .frame(height: makeTopOffset(viewHeight: ArrowsCapsuleView.height, screenHeight: screenHeight, index: viewModel.currentIndex))
                         standaloneScroller
                             .contentShape(Capsule())
                             .background(tappableAreaBackgroundColor)
                         Spacer(minLength: 0)
                     }
                     .offset(x: isVisible ? 0 : ArrowsCapsuleView.width)
                     .animation(.easeInOut, value: viewModel.currentIndex)
                     .padding(.vertical, -dimensions.scrollerPadding) // Allows scroller to go with content to the boundary
                 }
             }
            .simultaneousGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateSpace))
                    .onChanged { value in
                        let index = dimensions.getIndex(offset: value.location.y, screenHeight: screenHeight, itemsCount: viewModel.count)
                        viewModel.continueDragging(index)
                    }
                    .onEnded { _ in
                        viewModel.endDragging()
                    }
            )
        }
        .opacity(isVisible ? 1 : 0) // `withAnimation` doesn't work inside opacity. Need to use `onChange` below
        .onChange(of: viewModel.isVisible) { newValue in
            withAnimation {
                isVisible = newValue
            }
        }
        .overlay {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: BoundsPreferenceKey.self,
                    value: geometry.frame(in: .global)
                )
            }
        }
        .onPreferenceChange(BoundsPreferenceKey.self) { frame in
            height = frame.size.height
            DispatchQueue.main.async {
                let availableCount = dimensions.getAvailableCount(height: frame.size.height)
                viewModel.setAvailableCount(availableCount)
            }
        }
        .onChange(of: viewModel.currentIndex) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var tappableAreaBackgroundColor: Color {
        // Leave for UI elements debugging
//        Color.red.opacity(0.4)
        Color.clear
    }

    @ViewBuilder
    private func makeItems(screenHeight: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            makeYearsViews(screenHeight: screenHeight)
                .padding(.trailing, dimensions.datesTrailingOffset)
            makeMonthView(screenHeight: screenHeight)
                .padding(.trailing, dimensions.datesTrailingOffset)
            ArrowsCapsuleView()
                .animation(.easeInOut, value: viewModel.currentIndex)
                .offset(y: makeTopOffset(viewHeight: ArrowsCapsuleView.height, screenHeight: screenHeight, index: viewModel.currentIndex))
        }
        .frame(idealWidth: CGFloat.greatestFiniteMagnitude, idealHeight: CGFloat.greatestFiniteMagnitude)
    }

    private func makeMonthView(screenHeight: CGFloat) -> some View {
        ChangingDateCapsuleView(
            texts: viewModel.months,
            height: dimensions.bigItemHeight,
            index: Binding(get: { viewModel.currentIndex }, set: { _ in })
        )
        .animation(.easeInOut, value: viewModel.currentIndex)
        .offset(y: makeTopOffset(viewHeight: dimensions.bigItemHeight, screenHeight: screenHeight, index: viewModel.currentIndex))
    }

    private func makeTopOffset(viewHeight: CGFloat, screenHeight: CGFloat, index: Int) -> CGFloat {
        return dimensions.makeTopOffset(
            viewHeight: viewHeight,
            screenHeight: screenHeight,
            index: index,
            itemsCount: viewModel.count
        )
    }

    private var standaloneScroller: some View {
        ArrowsCapsuleView()
            .padding(.vertical, dimensions.scrollerPadding) // Creates interactive area for receiving drag gesture
            .padding(.leading, dimensions.scrollerPadding)  // Creates interactive area for receiving drag gesture
    }

    private func makeYearsViews(screenHeight: CGFloat) -> some View {
        ForEach(viewModel.years, id: \.id) { year in
            VStack(alignment: .trailing, spacing: 0) {
                Spacer()
                    .frame(height: makeTopOffset(viewHeight: dimensions.baseItemHeight, screenHeight: screenHeight, index: year.index))
                DateCapsuleView(text: year.text, height: dimensions.baseItemHeight)
                Spacer()
            }
        }
    }
}

private struct BoundsPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
