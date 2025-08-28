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

import Lottie
import PDCore
import SwiftUI
import ProtonCoreUIFoundations
import PDUIComponents

struct MigrationPlaceholderTexts: Equatable {
    let title: String
    let text: String
}

struct MigrationPlaceholderView: View {
    private let texts: MigrationPlaceholderTexts

    init(texts: MigrationPlaceholderTexts) {
        self.texts = texts
    }

    var body: some View {
        ZStack(alignment: .center) {
            VStack(alignment: .center, spacing: 32) {
                Spacer()
                try? makeImage()
                VStack(spacing: 16) {
                    titleView
                    textView
                }
                Spacer()
            }
            .padding(.horizontal, 32)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func makeImage() throws -> some View {
        let url = try Bundle.module.url(forResource: "MigrationAnimation", withExtension: "json") ?! "Invalid asset"
        let data = try Data(contentsOf: url)
        try LottieView(animation: .from(data: data))
            .playing(loopMode: .loop)
    }

    private var titleView: some View {
        Text(texts.title)
            .modifier(
                ResizableTextModifier(
                    alignment: .center,
                    font: .body,
                    fontWeight: .semibold,
                    textColor: ColorProvider.TextNorm
                )
            )
            .accessibilityIdentifier("MigrationPlaceholderView.title")
    }

    private var textView: some View {
        Text(texts.text)
            .modifier(
                ResizableTextModifier(
                    alignment: .center,
                    font: .subheadline,
                    textColor: ColorProvider.TextNorm
                )
            )
            .accessibilityIdentifier("MigrationPlaceholderView.text")
    }
}
