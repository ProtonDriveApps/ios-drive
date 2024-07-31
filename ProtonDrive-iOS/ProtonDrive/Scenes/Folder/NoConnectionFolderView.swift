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
import PDUIComponents

struct NoConnectionFolderView: View {
    @Binding var isUpdating: Bool
    @State private var didAlreadyShow = false
    let config: EmptyViewConfiguration
    var refresh: () -> Void
    
    init(
        isUpdating: Binding<Bool>,
        didAlreadyShow: Bool = false,
        config: EmptyViewConfiguration = .noConnection,
        refresh: @escaping () -> Void
    ) {
        _isUpdating = isUpdating
        self.didAlreadyShow = didAlreadyShow
        self.config = config
        self.refresh = refresh
    }
    
    var body: some View {
        EmptyFolderView(
            viewModel: config,
            footer: {
                Group {
                    BlueRectButton(
                        title: "Refresh",
                        foregroundColor: ColorProvider.TextNorm,
                        backgroundColor: ColorProvider.InteractionWeak,
                        font: .caption,
                        height: 32,
                        action: refresh
                    )
                    .fixedSize()
                    .padding(.top)

                    Spacer()
                }
            }
        )
        .onChange(
            of: isUpdating,
            perform: { _ in didAlreadyShow = true }
        )
        .opacity(isUpdating ? 0 : 1)
        .transition(.opacity)
        .animation(didAlreadyShow ? .default : nil)
    }
}

struct NoConnectionFolderView_Previews: PreviewProvider {
    static var previews: some View {
        NoConnectionFolderView(isUpdating: .constant(false), refresh: { })
            .previewDevice("iPhone X")
    }
}
