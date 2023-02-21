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
import Combine
import PDUIComponents
import ProtonCore_UIFoundations

struct ShareLinkDecryptionErrorView: View {
    @ObservedObject var vm: ShareLinkDecryptionErrorViewModel
    @EnvironmentObject var root: RootViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            EmptyFolderView(
                viewModel: EmptyViewConfiguration(
                    image: .genericError,
                    title: "",
                    message: "Failed to generate a secure link. Try again later."),
                footer: {
                    Group {
                        BlueRectButton(
                            title: "Delete Link",
                            foregroundColor: ColorProvider.TextNorm,
                            backgroundColor: ColorProvider.InteractionWeak,
                            font: .caption,
                            height: 32,
                            action: { vm.attemptDeleteLink = true }
                        )
                        .fixedSize()
                        .padding(.top)

                        Spacer()
                    }
                    .actionSheet(isPresented: $vm.attemptDeleteLink) {
                        ActionSheet(
                            title: Text(vm.stopSharingAlertTitle),
                            message: Text(vm.stopSharingAlertMessage),
                            buttons: [
                                .cancel(),
                                .destructive(
                                    Text(vm.stopSharingButton),
                                    action: vm.deleteLink
                                ),
                            ]
                        )
                    }
                }
            )
        }
        .edgesIgnoringSafeArea(.all)
        .onReceive(vm.$isScreenClosed) { output in
            guard output else { return }
            closeScreen()
        }
    }

    private func closeScreen() {
        root.closeCurrentSheet.send()
    }
}
