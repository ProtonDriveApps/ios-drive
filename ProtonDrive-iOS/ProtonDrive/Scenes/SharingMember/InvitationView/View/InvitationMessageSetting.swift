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
import PDLocalization

struct InvitationMessageSetting: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    private let handler: InvitationSheetHandler
    @State private var isIncludeMessage: Bool
    @State private var isVisible = false
    @State private var opacity: Double = 0
    
    init(isIncludeMessage: Bool, handler: InvitationSheetHandler) {
        self.isIncludeMessage = isIncludeMessage
        self.handler = handler
    }
    
    var body: some View {
        ZStack {
            Color(ColorProvider.BlenderNorm)
                .ignoresSafeArea(.all)
                .opacity(opacity)
                .onTapGesture {
                    dismiss()
                }
            
            VStack {
                Spacer()
                sheet
                    .transition(.move(edge: .bottom))
                    .offset(y: isVisible ? 0 : UIScreen.main.bounds.height * 0.5)
            }
        }
        .onAppear(perform: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = true
                opacity = 1
            }
        })
    }
    
    private var sheet: some View {
        VStack(spacing: 0) {
            Rectangle()
                .foregroundColor(ColorProvider.BackgroundNorm)
                .frame(height: 14)
                .cornerRadius(.huge, corners: [.topLeft, .topRight])
            
            sheetHeaderView
                .background(ColorProvider.BackgroundNorm)
            imageView()
                .background(ColorProvider.BackgroundNorm)
            optionRow
                .background(ColorProvider.BackgroundNorm)
            
            Text(Localization.sharing_member_include_message_info)
                .modifier(TextModifier(alignment: .center, fontSize: 11, textColor: ColorProvider.TextWeak))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 45)
                .padding(.vertical, 20)
                .background(ColorProvider.BackgroundNorm)
        }
    }
    
    private var sheetHeaderView: some View {
        HStack {
            
            Button(
                action: dismiss,
                label: {
                    AvatarView(
                        config: .init(
                            avatarSize: .init(width: 40, height: 40),
                            content: .right(IconProvider.cross),
                            backgroundColor: .clear,
                            foregroundColor: ColorProvider.IconNorm,
                            iconSize: .init(width: 24, height: 24)
                        )
                    )
                }
            )
            
            Spacer()
            Text(Localization.sharing_member_title_message_setting)
            Spacer()
            Button(Localization.general_done) {
                clickDoneButton()
            }
            .tint(ColorProvider.BrandNorm)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func imageView() -> some View {
        let resource = isIncludeMessage ? "share-message-setting-enable" : "share-message-setting-disable"
        Image(resource)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.vertical, 30)
            .padding(.horizontal, 32)
    }
    
    private var optionRow: some View {
        HStack(spacing: 8) {
            AvatarView(
                config: .init(
                    content: .right(IconProvider.envelope),
                    backgroundColor: .clear,
                    foregroundColor: ColorProvider.IconWeak
                )
            )
            Toggle(isOn: $isIncludeMessage) {
                Text(Localization.sharing_member_include_message)
                    .modifier(TextModifier(textColor: ColorProvider.TextNorm))
                    .padding(.vertical, 16)
            }
            .tint(ColorProvider.BrandNorm)
        }
        .padding(.horizontal, 16)
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
    
    private func clickDoneButton() {
        handler.update(includingMessage: isIncludeMessage)
        dismiss()
    }
}
