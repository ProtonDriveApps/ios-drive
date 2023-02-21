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
import ProtonCore_UIFoundations

final class ProtectViewController: UIViewController {
    private var cancellable: Cancellable?

    var viewModel: ProtectViewModel!
    var onLocked: (() -> Void)?
    var onUnlocked: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorProvider.BackgroundSecondary

        cancellable = viewModel
            .isLockedPublisher
            .removeDuplicates()
            .sink { [weak self] in self?.handleLockStatusChange($0) }

        #if DEBUG
        OnboardingFlowTestsManager.deafultOnboardingInTestsIfNeeded()
        logOutInTestsIfNeeded()
        #endif
    }

    private func handleLockStatusChange(_ isLocked: Bool) {
        if isLocked {
            onLocked?()
        } else {
            onUnlocked?()
        }
    }
}

#if DEBUG
extension ProtectViewController {
    private var testArgument: String { "--uitests" }
    private var clearArgument: String { "--clear_all_preference" }

    func logOutInTestsIfNeeded() {
        let arguments = CommandLine.arguments
        guard arguments.contains(testArgument),
              arguments.contains(clearArgument) else { return }

        cancellable?.cancel()
        cancellable = nil

        CommandLine.arguments = arguments
            .filter { $0 != clearArgument }

        viewModel.requestLogout()
    }
}
#endif
