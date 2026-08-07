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
import PDUIComponents

struct ShareMoreActionSheet: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @State private var isVisible = false
    @State private var opacity: Double = 0
    @ObservedObject private var viewModel: ShareMoreActionSheetViewModel
    @ObservedObject private var inviteeViewModel: InviteeViewModel

    init(viewModel: ShareMoreActionSheetViewModel, inviteeViewModel: InviteeViewModel) {
        self.viewModel = viewModel
        self.inviteeViewModel = inviteeViewModel
    }

    var body: some View {
        ZStack {
            Color(ColorProvider.BlenderNorm)
                .ignoresSafeArea(.all)
                .opacity(opacity)
                .accessibilityIdentifier("ShareMoreActionSheet.Background")
                .onTapGesture {
                    dismiss()
                }
            
            VStack {
                Spacer()
                sheet
                    .padding(.horizontal, 16)
                    .background(ColorProvider.BackgroundNorm)
                    .transition(.move(edge: .bottom))
                    .offset(y: isVisible ? 0 : UIScreen.main.bounds.height * 0.5)
            }
        }
        .disabled(viewModel.isDeleting)
        .onAppear(perform: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = true
                opacity = 1
            }
        })
    }
    
    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            if inviteeViewModel.editorAccessSetting.isVisible {
                accessSection
            }
            if inviteeViewModel.editorAccessSetting.isVisible, inviteeViewModel.canStopSharing {
                Divider()
                    .padding(.vertical, 8)
            }
            // Stopping sharing deletes the share for everyone — owner-only.
            if inviteeViewModel.canStopSharing {
                stopSharingSection
            }
        }
        .padding(.vertical, 16)
    }

    private var accessSection: some View {
        settingRow(
            title: inviteeViewModel.editorAccessSetting.sectionTitle,
            description: inviteeViewModel.editorAccessSetting.toggleTitle
        ) {
            Toggle(
                "",
                isOn: .init(
                    get: { inviteeViewModel.allowEditorsToManageSharing },
                    set: { inviteeViewModel.setAllowEditorsToManageSharing($0) }
                )
            )
            .labelsHidden()
            .tint(ColorProvider.BrandNorm)
            .disabled(inviteeViewModel.isUpdatingEditorAccess)
            .accessibilityIdentifier("ShareMoreActionSheet.allowEditorsToManageSharingToggle")
        }
    }

    private var stopSharingSection: some View {
        settingRow(
            title: viewModel.actionTitle,
            description: viewModel.actionSubtitle
        ) {
            if viewModel.isDeleting {
                ProtonSpinner(size: .medium)
            } else {
                Button {
                    viewModel.stopSharing()
                } label: {
                    Text(viewModel.actionTitle)
                        .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.NotificationError, maxWidth: nil))
                }
                .accessibilityIdentifier("ShareMoreActionSheet.Button.StopSharing")
            }
        }
    }

    /// A section row matching the web layout: bold title + grey description on the left, control on the right.
    @ViewBuilder
    private func settingRow<Control: View>(
        title: String,
        description: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .modifier(TextModifier(fontSize: 17, fontWeight: .semibold, textColor: ColorProvider.TextNorm))
                Text(description)
                    .modifier(TextModifier(fontSize: 13, textColor: ColorProvider.TextWeak))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.vertical, 12)
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
