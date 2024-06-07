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

struct ShareLinkView<SharedLink: View>: View {
    @ObservedObject private var vm: ShareLinkViewModel
    @EnvironmentObject private var root: RootViewModel

    private let sharedLinkView: SharedLink

    init(
        vm: ShareLinkViewModel,
        sharedLinkViewFactory: () -> SharedLink
    ) {
        self.vm = vm
        self.sharedLinkView = sharedLinkViewFactory()
    }
    
    var body: some View {
        Group {
            switch vm.state {
            case .loading(let message):
                LoadingView(text: message)
                    .animation(.default)

            case .sharing:
                sharedLinkView

                Spacer()
                    .actionSheet(isPresented: $vm.showNonCommitedChangesAlert) {
                        ActionSheet(
                            title: Text(""),
                            message: Text(vm.closeAlertModel.title),
                            buttons: [
                                .cancel(),
                                .default(Text(vm.closeAlertModel.primaryAction), action: vm.saveAndClose),
                                .default(Text(vm.closeAlertModel.secondaryAction), action: closeScreen),
                            ]
                        )
                    }
            }
        }
        .onReceive(vm.$shouldClose) { isClosed in
            guard isClosed else { return }
            closeScreen()
        }
    }

    private func closeScreen() {
        root.closeCurrentSheet.send()
    }
}
