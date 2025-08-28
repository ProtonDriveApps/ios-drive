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

struct TagsMigrationSheetView<ViewModel: TagsMigrationSheetViewModelProtocol>: View {
    private let viewModel: ViewModel
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
        VStack(spacing: 0) {
            try? makeImage()
                .frame(height: 227)
                .padding(.bottom, 24)
            Text(viewModel.headline)
                .modifier(
                    ResizableTextModifier(
                        alignment: .center,
                        font: .title2,
                        fontWeight: .bold,
                        textColor: ColorProvider.TextNorm
                    )
                )
                .padding(.bottom, 16)
                .accessibilityIdentifier("TagMigrationSheetView.headline")
            texts
                .padding(.bottom, 40)
            button
        }
    }

    @ViewBuilder
    private func makeImage() throws -> some View {
        let url = try Bundle.module.url(forResource: "TagMigrationAnimation", withExtension: "json") ?! "Invalid asset"
        let data = try Data(contentsOf: url)
        try LottieView(animation: .from(data: data))
            .playing(loopMode: .playOnce)
    }

    private var texts: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.items) { item in
                HStack {
                    ZStack {
                        Circle()
                            .fill(ColorProvider.BackgroundSecondary)
                            .frame(width: 28, height: 28)
                        iconView(icon: item.icon)
                    }

                    Text(item.desc)
                        .modifier(
                            ResizableTextModifier(
                                alignment: .leading,
                                font: .footnote,
                                textColor: ColorProvider.TextWeak
                            )
                        )
                        .accessibilityIdentifier("TagMigrationSheetView.text.\(item.id)")
                }
            }
        }
    }

    private func iconView(icon: TagsMigrationSheetViewModel.Icon) -> some View {
        let image: Image
        switch icon {
        case .rotate:
            image = IconProvider.arrowsRotate
        case .lock:
            image = IconProvider.lock
        case .rocket:
            image = IconProvider.rocket
        }

        return image
            .resizable()
            .frame(width: 16, height: 16)
            .foregroundStyle(ColorProvider.IconWeak)
            .accessibilityIdentifier("TagMigrationSheetView.icon.\(icon.rawValue)")
    }

    private var button: some View {
        VStack(spacing: 10) {
            BlueRectButton(title: viewModel.buttonTitle, cornerRadius: .huge) {
                dismiss()
            }
            .accessibilityIdentifier("MigrationSheetView.doneButton")
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isVisible = false
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            hostingProvider.viewController?.dismiss(animated: true)
        }
    }
}
