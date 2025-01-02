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

struct PublicLinkSettingView: View {
    @ObservedObject var viewModel: PublicLinkSettingViewModel
    @State private var presentShareSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.sharedLink.isLegacy {
                warningView
            } else {
                settingView
            }
            
            Spacer()
            
            if viewModel.enablePassword {
                copyPasswordButton()
                    .padding(.bottom, 8)
            }
        }
        .background(ColorProvider.BackgroundNorm)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                saveButton
            }
        }
    }
    
    private var warningView: some View {
        HStack(alignment: .center, spacing: 8) {
            IconProvider.infoCircle
                .resizable()
                .frame(width: 24, height: 24)

            Text(viewModel.legacyLinkWarning)
                .font(.callout)
                .foregroundColor(ColorProvider.TextWeak)
                .padding(.vertical)
        }
        .background(ColorProvider.BackgroundSecondary.cornerRadius(CornerRadius.huge))
        .padding(.horizontal, 16)
    }
    
    private var settingView: some View {
        VStack {
            sectionHeader
                .padding(.horizontal, 16)
            passwordSettingRow
                .padding(.top, 16)
                .padding(.horizontal, 16)
            if viewModel.enablePassword {
                passwordTextField
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .fill(ColorProvider.BackgroundSecondary)
                    .frame(height: 8)
                    .padding(.top, 20)
            }
            
            expirationDateSettingRow
                .padding(.top, 8)
                .padding(.horizontal, 16)
            if viewModel.enableExpirationDate {
                datePicker
                    .padding(.horizontal, 16)
            }
        }
        .disabled(viewModel.isSaving)
    }
    
    private var sectionHeader: some View {
        VStack(spacing: 0) {
            Rectangle()
                .foregroundColor(.clear)
                .frame(height: 24)
            Text(viewModel.sectionHeader)
                .modifier(TextModifier())
        }
    }
    
    private var passwordSettingRow: some View {
        Toggle(
            isOn: $viewModel.enablePassword,
            label: {
                HStack(spacing: 12) {
                    AvatarView(
                        config: .init(
                            content: .right(IconProvider.key),
                            backgroundColor: ColorProvider.BackgroundSecondary,
                            foregroundColor: ColorProvider.IconWeak
                        )
                    )
                    
                    Text(viewModel.passwordTitle)
                        .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm))
                }
            }
        )
        .tint(ColorProvider.BrandNorm)
        .accessibilityIdentifier("PublicLinkSettingsView.PasswordSwitch")
    }
    
    private var passwordTextField: some View {
        CharacterLimitTextField(
            isEnabled: $viewModel.enablePassword,
            text: $viewModel.password,
            maximumChars: viewModel.maximumPassword,
            placeholder: viewModel.passwordPlaceholder,
            title: ""
        )
        .frame(height: 80)
    }
    
    private var expirationDateSettingRow: some View {
        Toggle(
            isOn: $viewModel.enableExpirationDate,
            label: {
                HStack(spacing: 12) {
                    AvatarView(
                        config: .init(
                            content: .right(IconProvider.calendarGrid),
                            backgroundColor: ColorProvider.BackgroundSecondary,
                            foregroundColor: ColorProvider.IconWeak
                        )
                    )
                    
                    Text(viewModel.expirationDateTitle)
                        .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm))
                }
            }
        )
        .tint(ColorProvider.BrandNorm)
        .accessibilityIdentifier("PublicLinkSettingsView.ExpirationDateSwitch")
    }

    private var datePicker: some View {
        HStack(spacing: 0) {
            Rectangle()
                .frame(width: 8)
                .foregroundColor(.clear)
            DatePicker(
                "",
                selection: $viewModel.expirationDate,
                in: viewModel.dateRange,
                displayedComponents: .date
            )
            .datePickerStyle(CompactDatePickerStyle())
            .accessibilityIdentifier("PublicLinkSettingsView.ExpirationDatePicker")
            .labelsHidden()
            .accentColor(ColorProvider.InteractionNorm)
            .frame(minHeight: 48, alignment: .leading)
            
            Spacer()
        }
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).foregroundColor(ColorProvider.BackgroundSecondary))
    }

    @ViewBuilder
    private func copyPasswordButton() -> some View {
        let foreground: Color = viewModel.password.isEmpty ? ColorProvider.TextDisabled : ColorProvider.TextNorm
        let background: Color = viewModel.password.isEmpty ? ColorProvider.InteractionWeakDisabled : ColorProvider.InteractionWeak
        Button(
            action: {
                UIPasteboard.general.string = viewModel.password
            }, label: {
                HStack(alignment: .center, spacing: 8) {
                    Spacer()
                    AvatarView(
                        config: .init(
                            avatarSize: .init(width: 20, height: 20),
                            content: .right(IconProvider.squares),
                            backgroundColor: .clear,
                            foregroundColor: foreground,
                            iconSize: .init(width: 20, height: 20)
                        )
                    )
                    
                    Text(viewModel.copyPasswordButtonTitle)
                        .modifier(TextModifier(fontSize: 17, textColor: foreground, maxWidth: nil))
                        .padding(.vertical, 12)
                    Spacer()
                }
            }
        )
        .background(background)
        .cornerRadius(.huge)
        .padding(.horizontal, 23.5)
        .frame(height: 48)
        .disabled(viewModel.password.isEmpty)
    }
    
    private var saveButton: some View {
        Group {
            if viewModel.isSaving {
                ProtonSpinner(size: .medium)
            } else {
                Button(viewModel.saveButtonTitle) {
                    viewModel.saveChange()
                }
                .foregroundColor(viewModel.enableSaveButton ? ColorProvider.BrandNorm : ColorProvider.TextDisabled)
                .disabled(!viewModel.enableSaveButton)
            }
        }
    }
}
