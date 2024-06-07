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

import UIKit
import Combine
import Foundation
import PDCore
import ProtonCoreServices
import ProtonCoreAccountDeletion

final class DeleteAccountViewModel: ObservableObject, LogoutRequesting {

    @Published var isLoading: Bool = false
    @Published var presentAlert: Bool = false
    @Published var errorMessage: String = ""

    private var cancellables = Set<AnyCancellable>()
    private let apiService: APIService
    private let signoutManager: SignOutManager

    init(apiService: APIService, signoutManager: SignOutManager) {
        self.apiService = apiService
        self.signoutManager = signoutManager

        DriveNotification.signOut.publisher
            .sink { _ in
                Task {
                    NotificationCenter.default.post(.isLoggingOut)
                    await signoutManager.signOut()
                    NotificationCenter.default.post(.checkAuthentication)
                }
            }
            .store(in: &cancellables)
    }

    func initiateAccountDeletion(over viewController: UIViewController) {
        isLoading = true
        let accountDeletion = AccountDeletionService(api: apiService)
        accountDeletion.initiateAccountDeletionProcess(
            over: viewController,
            performAfterShowingAccountDeletionScreen: { [weak self] in
                self?.isLoading = false
            },
            completion: { [weak self] result in
                self?.isLoading = false
                switch result {
                case .success:
                    self?.processSuccessfulAccountDeletion()
                case .failure(AccountDeletionError.closedByUser):
                    break
                case .failure(let error):
                    self?.updateErrorMessage(error)
                }
            }
        )
    }

    private func processSuccessfulAccountDeletion() {
        requestLogout()
    }

    private func updateErrorMessage(_ error: AccountDeletionError) {
        errorMessage = error.userFacingMessageInAccountDeletion
        presentAlert = !errorMessage.isEmpty
    }

}
