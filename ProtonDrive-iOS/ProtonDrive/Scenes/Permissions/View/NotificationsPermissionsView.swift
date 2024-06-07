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

import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct NotificationsPermissionsView: View {
    let viewModel: NotificationsPermissionsViewModel
    
    var body: some View {
        if viewModel.data.isNavigationVisible {
            NavigatingView(title: "", leading: closeButton, trailing: EmptyView()) {
                content
            }
        } else {
            content
        }
    }
    
    private var content: some View {
        VStack {
            VStack(alignment: .center, spacing: 12) {
                Spacer()
                image
                texts
                Spacer()
            }
            .multilineTextAlignment(.center)
            buttons
        }
        .padding(24)
        .background(ColorProvider.BackgroundNorm)
    }

    private var image: some View {
        Image("notifications_permissions")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 140)
            .accessibilityIdentifier("NotificationsPermissions.Illustration")
    }

    private var texts: some View {
        VStack(spacing: 4) {
            Text(viewModel.data.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ColorProvider.TextNorm)
            Text(viewModel.data.description)
                .font(.headline)
                .fontWeight(.regular)
                .foregroundColor(ColorProvider.TextWeak)
        }
    }

    private var buttons: some View {
        VStack(spacing: 0) {
            BlueRectButton(
                title: viewModel.data.enableButton,
                cornerRadius: .huge,
                action: viewModel.enable
            )
            .accessibilityIdentifier("NotificationsPermissions.Button.Allow")
            LinkButton(
                title: viewModel.data.closeButton,
                action: viewModel.close
            )
            .accessibilityIdentifier("NotificationsPermissions.Button.NotNow")
        }
    }
    
    private var closeButton: some View {
        SimpleCloseButtonView {
            viewModel.close()
        }
    }
}
