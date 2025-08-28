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
import PDUIComponents
import ProtonCoreUIFoundations

struct PublicShareLinkView: View {
    @ObservedObject var viewModel: PublicShareLinkViewModel
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            sectionHeader
            component
                .padding(.vertical, 12)
            if viewModel.hasLink {
                copyLinkButton
                    .padding(.vertical, 10)
                settingButton
            }
        }
        .padding(.horizontal, 16)
        .onAppear(perform: {
            viewModel.prepareSharedLink()
        })
    }
    
    private var sectionHeader: some View {
        VStack(spacing: 0) {
            Text(viewModel.sectionHeader)
                .modifier(TextModifier(textColor: ColorProvider.TextHint))
                .padding(.top, 24)
                .padding(.bottom, 8)
        }
    }
    
    private var component: some View {
        HStack(spacing: 12) {
            iconView()
            if viewModel.isLoading {
                informationView
                ProtonSpinner(size: .custom(24))
                    .accessibilityIdentifier("public.share.link.spinner")
            } else {
                toggle {
                    informationView
                }
                .accessibilityIdentifier("public.share.link.toggle")
            }
        }
    }
    
    @ViewBuilder
    private func iconView() -> some View {
        let background: Color = viewModel.hasLink ? ColorProvider.NotificationSuccess.opacity(0.16) : ColorProvider.BackgroundSecondary
        let foreground: Color = viewModel.hasLink ? ColorProvider.NotificationSuccess : ColorProvider.IconWeak
        AvatarView(
            config: .init(
                content: .right(IconProvider.globe),
                backgroundColor: background,
                foregroundColor: foreground
            )
        )
    }
    
    private var informationView: some View {
        VStack(spacing: 0) {
            Text(viewModel.componentTitle)
                .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm))
            Menu(content: linkPermissionMenu, label: linkPermissionLabel)
                .disabled(viewModel.shouldDisableUpdatePermission)
        }
    }

    private func linkPermissionLabel() -> some View {
        let textColor: Color
        let iconColor: Color
        if viewModel.canEditPermission {
            if viewModel.shouldDisableUpdatePermission {
                textColor = ColorProvider.TextDisabled
                iconColor = ColorProvider.IconDisabled
            } else {
                textColor = ColorProvider.TextNorm
                iconColor = ColorProvider.IconNorm
            }
        } else {
            textColor = ColorProvider.TextHint
            iconColor = ColorProvider.IconNorm
        }
        return HStack {
            Text(viewModel.componentSubtitle)
                .modifier(
                    TextModifier(
                        fontSize: 13,
                        fontWeight: viewModel.canEditPermission ? .bold : .regular,
                        textColor: textColor,
                        maxWidth: nil
                    )
                )
                .accessibilityIdentifier("public.share.link.permission.\(viewModel.linkPermission.isEditor ? "canEdit" : "canView")")
            if viewModel.canEditPermission {
                AvatarView(
                    config: .init(
                        avatarSize: .init(width: 20, height: 20),
                        content: .right(IconProvider.chevronDown),
                        backgroundColor: .clear,
                        foregroundColor: iconColor,
                        iconSize: .init(width: 20, height: 20)
                    )
                )
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func linkPermissionMenu() -> some View {
        if viewModel.canEditPermission {
            Toggle(
                isOn: .init(
                    get: { !viewModel.linkPermission.isEditor },
                    set: { if $0 { viewModel.update(linkPermission: [.read]) } }
                ),
                label: {
                    Text(viewModel.canViewText)
                    IconProvider.eye
                }
            )
            .accessibilityIdentifier("public.share.link.read.menu.button")
            
            Toggle(
                isOn: .init(
                    get: { viewModel.linkPermission.isEditor },
                    set: { if $0 { viewModel.update(linkPermission: [.read, .write]) } }
                ),
                label: {
                    Text(viewModel.canEditText)
                    IconProvider.pen
                }
            )
            .accessibilityIdentifier("public.share.link.edit.menu.button")
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func menuItem(isSelected: Bool, text: String, icon: Image) -> some View {
        HStack {
            if isSelected { IconProvider.checkmark }
            Text(text)
            icon
        }
    }
    
    @ViewBuilder
    private func toggle(informationView: () -> some View) -> some View {
        Toggle(
            isOn: Binding(
                get: { viewModel.hasLink },
                set: { value in
                    if value {
                        viewModel.createLink()
                    } else {
                        showAlert = true
                    }
                }
            ),
            label: {
                informationView()
            }
        )
        .tint(ColorProvider.BrandNorm)
        .confirmationDialog(
            viewModel.stopSharingAlertTitle,
            isPresented: $showAlert,
            titleVisibility: .visible,
            actions: {
                Button(viewModel.stopSharingAlertTitle, role: .destructive, action: { viewModel.deleteLink() })
                    .accessibilityIdentifier("PublicShareLinkView.ConfirmationDialog.Button.StopSharing")
            }, message: {
                Text(viewModel.stopSharingAlertMessage)
            }
        )
    }
    
    private var copyLinkButton: some View {
        Button(
            action: {
                guard let url = viewModel.prepareLink() else { return }
                UIPasteboard.general.string = url
                viewModel.presentCopiedLinkBanner()
            },
            label: {
                HStack(alignment: .center, spacing: 8) {
                    Spacer()
                    AvatarView(
                        config: .init(
                            avatarSize: .init(width: 20, height: 20),
                            content: .right(IconProvider.link),
                            backgroundColor: .clear,
                            foregroundColor: ColorProvider.IconNorm,
                            iconSize: .init(width: 20, height: 20)
                        )
                    )
                    
                    Text(viewModel.copyLinkTitle)
                        .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm, maxWidth: nil))
                        .padding(.vertical, 12)
                    Spacer()
                }
            }
        )
        .frame(height: 48)
        .padding(.horizontal, 23.73)
        .background(ColorProvider.InteractionWeak)
        .cornerRadius(.huge)
    }
    
    private var settingButton: some View {
        Button(
            action: {
                viewModel.openSettingPage()
            }, label: {
                HStack(alignment: .center) {
                    Spacer()
                    Text(viewModel.settingButtonTitle)
                        .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm, maxWidth: nil))
                        .padding(.vertical, 12)
                    Spacer()
                }
            }
        )
        .frame(height: 48)
        .padding(.horizontal, 23.73)
        .background(ColorProvider.InteractionWeak)
        .cornerRadius(.huge)
    }
}
