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
import SwiftUI
import PDUIComponents
import ProtonCoreUIFoundations

struct SharingConfigView: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @ObservedObject private var viewModel: SharingConfigViewModel
    @ObservedObject private var inviteeViewModel: InviteeViewModel
    @State var isShared = false
    private let inviteeListView: InviteeListView
    private let publicShareLinkView: PublicShareLinkView
    
    init(
        viewModel: SharingConfigViewModel,
        inviteeViewModel: InviteeViewModel,
        inviteeListView: InviteeListView,
        publicShareLinkView: PublicShareLinkView
    ) {
        self.viewModel = viewModel
        self.inviteeViewModel = inviteeViewModel
        self.inviteeListView = inviteeListView
        self.publicShareLinkView = publicShareLinkView
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.hasSharingInvitations {
                    if viewModel.hasPublicLinkView {
                        publicShareLinkView
                    }
                    inviteeListView
                        .environmentObject(hostingProvider)

                } else {
                    publicShareLinkView
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(ColorProvider.BackgroundNorm)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                dismissButton
            }
            if inviteeViewModel.canOpenMoreActions {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
        }
        .onAppear(perform: {
            viewModel.viewAppear()
        })
    }

    private var dismissButton: some View {
        Button {
            hostingProvider.viewController?.navigationController?.dismiss(animated: true)
        } label: {
            Image(uiImage: IconProvider.cross)
                .tint(ColorProvider.IconNorm)
        }
        .accessibilityIdentifier("SharingConfigView.closeButton")
    }

    /// Single entry point to the "more" sheet (stop sharing + owner-only editor-access setting).
    /// Disabled until a share exists.
    private var settingsButton: some View {
        Button {
            viewModel.presentMoreActionSheet(inviteeViewModel: inviteeViewModel)
        } label: {
            Image(uiImage: IconProvider.cogWheel)
                .tint(ColorProvider.IconNorm)
        }
        .disabled(!viewModel.isShared)
        .accessibilityIdentifier("SharingConfigView.settingsButton")
    }
}
