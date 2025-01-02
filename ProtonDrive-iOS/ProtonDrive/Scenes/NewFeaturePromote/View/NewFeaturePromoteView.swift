// Copyright (c) 2024 Proton AG
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
import PDUIComponents
import ProtonCoreUIFoundations
import PDLocalization

struct NewFeaturePromoteView<ViewModel: NewFeaturePromoteViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @State private var isVisible = false
    @State private var opacity: Double = 0
    @State private var tabViewHeight: CGFloat?
    @State private var verticalOffset: CGFloat = 0
    private var features: [NewFeatureModel] {
        viewModel.features
    }

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
                    DragGesture()
                        .onChanged { value in
                            // Could be iOS bug, when offset is too small, e.g. 8 px
                            // onEnded won't be fired so verticalOffset doesn't have chance to be reset
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
                viewModel.didAppear()
            })
        })
    }
    
    @ViewBuilder
    private func sheet(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            sheetHead
            VStack(spacing: 0) {
                title
                    .padding(.top, 16)
                carousel(geometry: geometry)
                    .padding(.bottom, 24)
                doneButton
                    .padding(.bottom, 24 + geometry.safeAreaInsets.bottom)
            }
            .padding(.horizontal, 16)
        }
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
    
    private var title: some View {
        Text(Localization.new_feature_title)
            .modifier(ResizableTextModifier(font: .title2, fontWeight: .bold, textColor: ColorProvider.TextNorm))
            .accessibilityIdentifier("NewFeature.sheet.title")
    }
    
    @ViewBuilder
    private func carousel(geometry: GeometryProxy) -> some View {
        VStack {
            TabView(selection: $viewModel.currentIndex.animation()) {
                ForEach(0..<features.count, id: \.self) { idx in
                    featureView(feature: features[idx], geometry: geometry)
                        .tag(idx)
                        .background(sizeChecker)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: tabViewHeight)
            .padding(.bottom, features.count > 1 ? 24 : 0)
            .accessibilityIdentifier("NewFeature.carousel")

            if features.count > 1 {
                pageIndex()
            }
        }
    }
    
    // TabView's index doesn't support style change
    // If you want to change color, needs to change global color by `UIPageControl.appearance()`
    // So implement index
    private func pageIndex() -> some View {
        HStack(spacing: 6) {
            ForEach(0..<features.count, id: \.self) { idx in
                if idx == viewModel.currentIndex {
                    Rectangle()
                        .fill(ColorProvider.InteractionNorm)
                        .frame(width: 24)
                        .cornerRadius(.huge)
                } else {
                    Rectangle()
                        .fill(ColorProvider.Shade20)
                        .frame(width: 6)
                        .cornerRadius(6)
                }
            }
        }
        .frame(height: 6)
    }
    
    private var sizeChecker: some View {
        GeometryReader(content: { geometry in
            Color.clear.onAppear {
                if tabViewHeight == nil {
                    // Otherwise TabView will occupy the whole screen 
                    tabViewHeight = geometry.size.height
                }
            }
        })
    }
    
    @ViewBuilder
    private func featureView(feature: NewFeatureModel, geometry: GeometryProxy) -> some View {
        // Image size is 343 x 228. In smaller screens it has to be scaled down to fit.
        let imageSize = CGSize(width: 343, height: 228)
        let screenWidth = geometry.size.width - 16 * 2
        let scale = min(1, screenWidth / imageSize.width) // only scale down if needed
        VStack(spacing: 0) {
            Image(feature.illustration)
                .resizable()
                .frame(width: imageSize.width * scale, height: imageSize.height * scale)
                .aspectRatio(contentMode: .fit)
                .cornerRadius(.extraHuge)
                .padding(.vertical, 24)
                .accessibilityIdentifier("NewFeature.illustration.\(feature.id)")

            Text(feature.title)
                .modifier(
                    ResizableTextModifier(
                        alignment: .center,
                        font: .body,
                        fontWeight: .bold,
                        textColor: ColorProvider.TextNorm
                    )
                )
                .padding(.bottom, 4)
                .accessibilityIdentifier("NewFeature.title.\(feature.id)")

            Text(feature.description)
                .modifier(
                    ResizableTextModifier(
                        alignment: .center,
                        font: .subheadline,
                        textColor: ColorProvider.TextWeak
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("NewFeature.desc.\(feature.id)")
        }
    }
    
    private var doneButton: some View {
        Button(
            action: {
                switch viewModel.button.action {
                case .close:
                    dismiss()
                case .next:
                    viewModel.showNext()
                }
            }, label: {
                VStack {
                    Text(viewModel.button.title)
                        .modifier(ResizableTextModifier(alignment: .center, font: .body, textColor: .white))
                        .padding(.vertical, 10)
                }
                .background(ColorProvider.BrandNorm)
                .cornerRadius(.huge)
            }
        )
        .frame(minHeight: 44)
        .accessibilityIdentifier("NewFeature.doneButton")
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
