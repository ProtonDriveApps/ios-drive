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

import Combine
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct PhotoPreviewLoadingStateView<ViewModel: PhotoPreviewLoadingStateViewModelProtocol>: View {
    @ObservedObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        content
            .onAppear {
                viewModel.onAppear()
            }
            .alert(item: $viewModel.alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text(alert.button)))
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .loading:
            Button(action: {
                viewModel.invokeAction()
            }, label: {
                ProtonSpinner(size: .custom(20), style: .inverted)
            })
        case .exclamationMark:
            Button(action: {
                viewModel.invokeAction()
            }, label: {
                IconProvider.exclamationCircle
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(ColorProvider.White)
                    .frame(width: 20, height: 20)
            })
        case .empty:
            EmptyView()
        }
    }
}
