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
    
    init(viewModel: ShareMoreActionSheetViewModel) {
        self.viewModel = viewModel
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
        Button(
            action: {
                viewModel.stopSharing()
            },
            label: {
                HStack(spacing: 12) {
                    crossIcon
                    textView
                        .padding(.vertical, 12)
                    if viewModel.isDeleting {
                        ProtonSpinner(size: .medium)
                    }
                }
            }
        )
        .accessibilityIdentifier("ShareMoreActionSheet.Button.StopSharing")
    }
    
    private var crossIcon: some View {
        AvatarView(
            config: .init(
                avatarSize: .init(width: 24, height: 24),
                content: .right(IconProvider.cross),
                backgroundColor: .clear,
                foregroundColor: ColorProvider.NotificationError,
                iconSize: .init(width: 24, height: 24)
            )
        )
    }
    
    private var textView: some View {
        VStack {
            Text(viewModel.actionTitle)
                .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.NotificationError))
            Text(viewModel.actionSubtitle)
                .modifier(TextModifier(fontSize: 13, textColor: ColorProvider.TextWeak))
        }
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
