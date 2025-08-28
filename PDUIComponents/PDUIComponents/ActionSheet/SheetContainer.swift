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

public struct SheetContainer<Content: View>: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @State private var isVisible = false
    @State private var opacity: Double = 0
    @State private var tabViewHeight: CGFloat?
    @State private var verticalOffset: CGFloat = 0
    private var contentView: Content

    public init(contentView: Content) {
        self.contentView = contentView
    }

    public var body: some View {
        GeometryReader(content: { geometry in
            ZStack {
                Color(ColorProvider.BlenderNorm)
                    .ignoresSafeArea(.all)
                    .opacity(opacity)
                    .onTapGesture {
                        dismiss()
                    }

                VStack(spacing: 0) {
                    Spacer()
                    sheet(geometry: geometry)
                        .transition(.move(edge: .bottom))
                        .background(
                            ColorProvider.BackgroundNorm
                                .cornerRadius(.extraLarge, corners: [.topLeft, .topRight])
                        )
                }
                .offset(y: verticalOffset)
                .offset(y: isVisible ? 0 : geometry.size.height)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let horizontalOffset = value.translation.width
                            let verticalOffset = value.translation.height
                            guard abs(verticalOffset) > abs(horizontalOffset) else { return }
                            self.verticalOffset = max(0, verticalOffset)
                        }
                        .onEnded { value in
                            if value.predictedEndTranslation.height > geometry.size.height - 50 {
                                dismiss()
                            } else {
                                withAnimation(.spring()) {
                                    verticalOffset = 0
                                }
                            }
                        }
                )

            }
            .ignoresSafeArea()
            .onAppear(perform: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisible = true
                    opacity = 1
                }
            })
        })
    }

    @ViewBuilder
    private func sheet(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            dragBarView
                .padding(.bottom, 6)
            contentView
                .environmentObject(hostingProvider)
                .padding(.horizontal, 16)
            Spacer().frame(height: geometry.safeAreaInsets.bottom)
        }
    }

    private var dragBarView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.clear)
                .frame(height: 8)
            HStack {
                Spacer()
                Rectangle()
                    .fill(ColorProvider.Shade40)
                    .frame(width: 46)
                    .cornerRadius(.extraHuge)
                Spacer()
            }
            .frame(height: 4)
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = false
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            hostingProvider.viewController?.dismiss(animated: false)
        }
    }
}
#endif
