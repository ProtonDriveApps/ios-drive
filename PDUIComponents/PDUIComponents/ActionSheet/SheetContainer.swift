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
    private var isBackgroundTapDismissEnabled: Bool
    private var isDragDismissEnabled: Bool

    public init(
        contentView: Content,
        isBackgroundTapDismissEnabled: Bool = true,
        isDragDismissEnabled: Bool = true
    ) {
        self.contentView = contentView
        self.isBackgroundTapDismissEnabled = isBackgroundTapDismissEnabled
        self.isDragDismissEnabled = isDragDismissEnabled
    }

    public var body: some View {
        GeometryReader(content: { geometry in
            ZStack {
                Color(ColorProvider.BlenderNorm)
                    .ignoresSafeArea(.all)
                    .opacity(opacity)
                    .onTapGesture {
                        if isBackgroundTapDismissEnabled {
                            dismiss()
                        }
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
                .gesture(dragGesture(geometry: geometry))

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

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard isDragDismissEnabled else { return }
                let horizontalOffset = value.translation.width
                let verticalOffset = value.translation.height
                guard abs(verticalOffset) > abs(horizontalOffset) else { return }
                self.verticalOffset = max(0, verticalOffset)
            }
            .onEnded { value in
                guard isDragDismissEnabled else { return }
                if value.predictedEndTranslation.height > geometry.size.height - 50 {
                    dismiss()
                } else {
                    withAnimation(.spring()) {
                        verticalOffset = 0
                    }
                }
            }
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
