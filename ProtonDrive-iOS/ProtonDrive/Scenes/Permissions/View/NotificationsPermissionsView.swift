//
//  NotificationsPermissionsView.swift
//  ProtonDrive
//
//  Created by Jan Halousek on 01.02.2023.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import PDUIComponents
import ProtonCore_UIFoundations
import SwiftUI

struct NotificationsPermissionsView: View {
    let viewModel: NotificationsPermissionsViewModel
    
    var body: some View {
        NavigatingView(title: "", leading: closeButton, trailing: EmptyView()) {
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
            Text("Turn on notifications")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ColorProvider.TextNorm)
            Text("We’ll notify you if there are any interruptions to your uploads or downloads.")
                .font(.headline)
                .fontWeight(.regular)
                .foregroundColor(ColorProvider.TextWeak)
        }
    }
    
    private var buttons: some View {
        VStack(spacing: 0) {
            BlueRectButton(
                title: "Allow notifications",
                cornerRadius: .huge,
                action: viewModel.enable
            )
            .accessibilityIdentifier("NotificationsPermissions.Button.Allow")
            LinkButton(
                title: "Not now",
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
