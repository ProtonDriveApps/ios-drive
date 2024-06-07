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
import ProtonCoreUIFoundations
import PDUIComponents

struct NodeListSecondLineView: View {
    let vm: NodeListSecondLine
    let parentIdentifier: String

    var body: some View {
        Group {
            Group {
                switch vm.figure {
                case .uploadSpinner, .spinner:
                    ProtonSpinner(size: .small)

                case .paused:
                    RoundIconSmall(icon: IconProvider.pause, color: ColorProvider.TextWeak)

                case .warning:
                    WarningBadgeView()

                case .badges(let badges):
                    badgeIcons(from: badges)
                }
            }
            .frame(width: 16, height: 16)
            .padding(.trailing, 4)

            Text(vm.subtitle)
                .accessibility(identifier: parentIdentifier)
                .font(.caption)
                .foregroundColor(vm.isFailedStyle ? ColorProvider.NotificationError : ColorProvider.TextWeak)
        }
    }

    @ViewBuilder
    func badgeIcons(from badges: [Badge]) -> some View {
        if badges.contains(.cloud) {
            RoundIconSmall(icon: IconProvider.cloud, color: ColorProvider.TextWeak)
                .accessibilityIdentifier("\(parentIdentifier).RoundIconSmall.cloud")
        }
        
        if badges.contains(.shared) {
            RoundIconSmall(icon: IconProvider.link, color: ColorProvider.TextWeak)
                .accessibilityIdentifier("\(parentIdentifier).RoundIconSmall.shared")
        }

        if badges.contains(.offline(downloaded: true)) {
            RoundIconSmall(icon: IconProvider.arrowDownCircle, color: ColorProvider.TextWeak)
                .accessibilityIdentifier("\(parentIdentifier).RoundIconSmall.offline")
        }
    }
}
