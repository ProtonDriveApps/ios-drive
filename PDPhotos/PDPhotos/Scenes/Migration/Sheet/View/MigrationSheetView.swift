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
import PDCore
import PDUIComponents
import ProtonCoreUIFoundations
import Lottie

struct MigrationSheetView<ViewModel: MigrationSheetViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @State private var isVisible = false
    @State private var opacity: Double = 0
    @State private var tabViewHeight: CGFloat?
    @State private var verticalOffset: CGFloat = 0

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        GeometryReader(content: { geometry in
            ZStack {
                Color(ColorProvider.BlenderNorm)
                    .ignoresSafeArea(.all)
                    .opacity(opacity)
                    .onTapGesture {
                        dismissWithoutAction()
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
                                dismissWithoutAction()
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
            sheetHead
            contentView(geometry: geometry)
                .padding(.top, 20)
                .padding(.bottom, geometry.safeAreaInsets.bottom)
        }
        .padding(.horizontal, 16)
    }

    private var sheetHead: some View {
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

    @ViewBuilder
    private func contentView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            Text(viewModel.data.headline)
                .modifier(
                    ResizableTextModifier(
                        alignment: .leading,
                        font: .title2,
                        fontWeight: .bold,
                        textColor: ColorProvider.TextNorm
                    )
                )
                .accessibilityIdentifier("MigrationSheetView.headline")
            try? makeImage()
            texts
            buttons
        }
    }

    @ViewBuilder
    private func makeImage() throws -> some View {
        let url = try Bundle.module.url(forResource: "MigrationAnimation", withExtension: "json") ?! "Invalid asset"
        let data = try Data(contentsOf: url)
        try LottieView(animation: .from(data: data))
            .playing(loopMode: .loop)
    }

    private var texts: some View {
        VStack(spacing: 4) {
            Text(viewModel.data.title)
                .modifier(
                    ResizableTextModifier(
                        alignment: .center,
                        font: .body,
                        fontWeight: .semibold,
                        textColor: ColorProvider.TextNorm
                    )
                )
                .padding(.bottom, 4)
                .accessibilityIdentifier("MigrationSheetView.title")
            Text(viewModel.data.subtitle)
                .modifier(
                    ResizableTextModifier(
                        alignment: .center,
                        font: .subheadline,
                        textColor: ColorProvider.TextWeak
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("MigrationSheetView.subtitle")
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            BlueRectButton(title: viewModel.data.startTitle, cornerRadius: .huge) {
                viewModel.start()
                dismiss()
            }
            .accessibilityIdentifier("MigrationSheetView.doneButton")
            TextButton(title: viewModel.data.remindLaterTitle) {
                viewModel.remindLater()
                dismiss()
            }
            .accessibilityIdentifier("MigrationSheetView.remindButton")
        }
    }

    private func dismissWithoutAction() {
        viewModel.willCloseWithoutAction()
        dismiss()
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = false
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            viewModel.close()
        }
    }
}
