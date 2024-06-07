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
import ProtonCoreUIFoundations

struct OnboardingPage: View {
    let vm: OnboardingPageViewModel
    let horizontalPadding: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Image(vm.imageName)
                    .aspectRatio(contentMode: .fit)
                    .background(ColorProvider.BackgroundSecondary)
                    .frame(height: geometry.size.height / 2, alignment: .center)
                    .accessibilityIdentifier("OnboardingPage.imageIdentifier")
                
                VStack {
                    Text(vm.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.vertical)
                        .accessibilityIdentifier("OnboardingPage.titleIdentifier")
                    
                    Text(vm.text)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("OnboardingPage.textIdentifier")
                    
                    Spacer()
                }
                .foregroundColor(ColorProvider.TextNorm)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: .infinity)
                .background(ColorProvider.BackgroundNorm)
            }
        }
    }
}
