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

struct EditLinkView: View {
    @ObservedObject var vm: EditLinkViewModel

    var body: some View {
        ListSection(header: vm.sectionTitle) {
            Group {
                if vm.isLegacy {
                    nonEditable
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                } else {
                    editable
                        .padding(.horizontal)
                        .padding(.vertical, 24)
                }
            }
        }
    }

    var editable: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.passwordTitle)
                    .font(.callout)
                    .fontWeight(.semibold)

                HStack {
                    textField

                    Button(action: { vm.isSecure.toggle() }, label: { textFieldIcon })
                }
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .frame(minHeight: 48)
                        .foregroundColor(ColorProvider.BackgroundSecondary)
                )
                .foregroundColor(ColorProvider.TextNorm)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(textFieldColor, lineWidth: 1)
                        .frame(minHeight: 48)
                )
                .frame(minHeight: 48)

                textFieldLegend
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.expirationDateTitle)
                    .font(.callout)
                    .fontWeight(.semibold)

                HStack {
                    datePicker
                        .padding(.trailing)
                        .background(RoundedRectangle(cornerRadius: 10).foregroundColor(ColorProvider.BackgroundSecondary))
                        .onTapGesture {
                            vm.hasExpirationDate = true
                        }

                    Toggle("", isOn: $vm.hasExpirationDate)
                        .toggleStyle(SwitchToggleStyle(tint: ColorProvider.InteractionNorm))
                        .labelsHidden()
                }
            }
        }
    }

    var nonEditable: some View {
        HStack(alignment: .center, spacing: 8) {
            IconProvider.infoCircle
                .resizable()
                .frame(width: 24, height: 24)

            Text("This link was created with an old Drive version and can not be modified. Delete this link and create a new one to change the settings.")
                .font(.callout)
                .foregroundColor(ColorProvider.TextWeak)
        }
        .padding()
        .background(ColorProvider.BackgroundSecondary.cornerRadius(CornerRadius.huge))
    }

    private var textFieldColor: Color {
        switch vm.password.count {
        case .zero:
            return ColorProvider.BackgroundSecondary
        case ...vm.maximumPasswordSize:
            return ColorProvider.InteractionNorm
        default:
            return ColorProvider.NotificationError
        }
    }

    private var textFieldLegend: some View {
        Group {
            if vm.password.count <= vm.maximumPasswordSize {
                Text("\(vm.password.count)/\(vm.maximumPasswordSize)")
                    .font(.caption)
                    .foregroundColor(ColorProvider.TextHint)
            } else {
                HStack {
                    WarningBadgeView()
                        .frame(width: 14, height: 14)

                    Text("Only \(vm.maximumPasswordSize) characters are allowed.")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .foregroundColor(ColorProvider.NotificationError)
            }
        }
        .font(.caption)
    }

    private var textField: some View {
        Group {
            if vm.isSecure {
                SecureField(vm.passwordPlaceholder, text: $vm.password)
            } else {
                TextField(vm.passwordPlaceholder, text: $vm.password)
                    .disableAutocorrection(true)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isSecure)
    }

    private var datePicker: some View {
        HStack {
            if vm.hasExpirationDate {
                DatePicker("", selection: $vm.expirationDate, in: vm.dateRange, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .padding(.horizontal)
                    .labelsHidden()
                    .accentColor(ColorProvider.InteractionNorm)
                    .frame(minHeight: 48, alignment: .leading)
            } else {
                Text(vm.datePickerPlaceholder)
                    .foregroundColor(ColorProvider.TextHint)
                    .padding(.leading)
                    .frame(minHeight: 48, alignment: .leading)
            }

            Spacer()
        }
    }

    var textFieldIcon: Image {
        vm.isSecure ? IconProvider.eye : IconProvider.eyeSlash
    }
}
