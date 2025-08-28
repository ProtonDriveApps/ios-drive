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
import ProtonCoreUIFoundations

struct PhotosStateAdditionalInfoView<ViewModel: PhotosStateAdditionalInfoViewModel>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        viewModel.texts.map(makeTexts)
    }

    private func makeTexts(from texts: [String]) -> some View {
        VStack(alignment: .leading) {
            ForEach(texts, id: \.self) { text in
                Text(text)
                    .foregroundColor(ColorProvider.TextNorm)
                    .font(.caption)
            }
        }
    }
}
