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

import SwiftUI
import PDUIComponents
import ProtonCoreUIFoundations
import PDCore
import PDLocalization

struct OnboardingFlow: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var currentPage: Int = 0
    let settings: LocalSettings
    let pages: [OnboardingPageViewModel]
    let bottomPadding = 14.0
    let horizontalPadding = 32.0
    
    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(pages.startIndex..<pages.endIndex, id: \.self) { pageIndex in
                let isLastPage = pageIndex.advanced(by: 1) == pages.endIndex
                
                ZStack {
                    OnboardingPage(vm: pages[pageIndex], horizontalPadding: horizontalPadding)
                        .padding(.bottom, -1 * bottomPadding)
                    
                    if !isLastPage {
                        skipButton
                            .scenePadding()
                    }
                    
                    nextButton(isLast: isLastPage)
                        .padding(.bottom, 3 * bottomPadding)
                        .padding(.horizontal, horizontalPadding)
                }
            }
        }
        .padding(.bottom, bottomPadding)
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()
    }
    
    var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                
                LightButton(title: Localization.general_skip, color: ColorProvider.BrandNorm, font: .body, action: dismiss)
            }
            
            Spacer()
        }
        .accessibilityLabel("OnboardingPage.skipButton")
    }
    
    func nextButton(isLast: Bool) -> some View {
        VStack {
            Spacer()
            
            if isLast {
                BlueRectButton(title: Localization.onboarding_button_get_started) {
                    dismiss()
                }
                .cornerRadius(8)
            } else {
                BlueRectButton(title: Localization.onboarding_button_next) {
                    withAnimation {
                        currentPage += 1
                    }
                }
                .cornerRadius(8)
            }
        }
        .accessibilityIdentifier("OnboardingPage.nextButton")
    }
    
    func dismiss() {
        settings.isOnboarded = true
        presentationMode.wrappedValue.dismiss()
    }
}
