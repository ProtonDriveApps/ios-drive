//
//  InitialPasswordConfigurationViewModel.swift
//  ProtonCore-Settings - Created on 04.10.2020.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import UIKit
import ProtonCoreUIFoundations
import PDLocalization

final class InitialPasswordConfigurationViewModel: PasswordConfigurationViewModel {
    private let router: SecurityPasswordRouter
    private let passwordSelector: PasswordSelector

    var rightNavigationButtonEnabled: Observer<Bool>?
    private var couldFinishStepSuccessfully = false

    init(passwordSelector: PasswordSelector, router: SecurityPasswordRouter) {
        self.router = router
        self.passwordSelector = passwordSelector
    }

    func userInputDidChange(to text: String) {
        do {
            try passwordSelector.setInitialPassword(to: text)
            rightNavigationButtonEnabled?(true)
        } catch {
            rightNavigationButtonEnabled?(false)
        }
    }

    func withdrawFromScreen() {
        router.withdraw()
    }

    func advance() {
        couldFinishStepSuccessfully = true
        router.advance()
    }
    
    func viewWillDisappear() {
        guard !couldFinishStepSuccessfully else { return }
        router.finishWithSuccess(false)
    }

    var title: String {
        Localization.password_config_title_use_pin
    }

    var buttonText: String {
        Localization.password_config_next_step
    }

    var caption: String {
        Localization.password_config_caption
    }

    var textFieldTitle: String {
        Localization.password_config_textfield_title
    }

    var rightBarButtonImage: UIImage {
        IconProvider.cross
    }
}
