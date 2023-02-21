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
import ProtonCore_UIFoundations
import ProtonCore_CoreTranslation

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
            Alert(title: Text("Account Deletion Error"), message: Text(vm.errorMessage))
        }
    }

    var deleteButton: some View {
        Button(CoreString._ad_delete_account_button, action: action)
            .foregroundColor(Color.NotificationError)
            .contentShape(Rectangle())
            .disabled(vm.isLoading)
    }
}
