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
import PDUIComponents
import ProtonCoreUIFoundations
import ProtonCoreAccountDeletion
import PDLocalization

struct DeleteAccountView: View {

    @ObservedObject var vm: DeleteAccountViewModel

    var action: () -> Void = {}

    var body: some View {
        VStack {
            Divider()
            ZStack {
                deleteButton
                if vm.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorProvider.BrandNorm))
                            .padding(.horizontal)
                    }
                }
            }
            Divider()

        }
        .alert(isPresented: $vm.presentAlert) {
            Alert(title: Text(Localization.account_deletion_alert_title), message: Text(vm.errorMessage))
        }
    }

    var deleteButton: some View {
        Button(ADTranslation.delete_account_button.l10n, action: action)
            .foregroundColor(Color.NotificationError)
            .contentShape(Rectangle())
            .disabled(vm.isLoading)
    }
}
