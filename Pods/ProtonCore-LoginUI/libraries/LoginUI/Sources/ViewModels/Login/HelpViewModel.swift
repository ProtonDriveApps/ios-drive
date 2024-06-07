//
//  HelpViewModel.swift
//  ProtonCore-LoginUI - Created on 16/03/2022.
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

#if os(iOS)

import Foundation
import ProtonCoreLogin
import ProtonCoreUtilities

final class HelpViewModel {

    let helpSections: [[HelpItem]]

    init(helpDecorator: ([[HelpItem]]) -> [[HelpItem]]) {
        let defaultHelp: [[HelpItem]] = [
            [
                .forgotUsername,
                .forgotPassword,
                .otherIssues
            ],
            [
                .staticText(text: LUITranslation.help_more_help.l10n)
            ],
            [
                .support
            ]
        ]
        helpSections = helpDecorator(defaultHelp)
    }
}

#endif
