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

import PDCoreIOS
import PDUIComponents
import ProtonCoreUIFoundations
import SwiftUI

struct BadgeGroupView: View {
    let badges: [Badge]
    let featureFlagsController: FeatureFlagsControllerProtocol
    let isGridView: Bool
    let parentIdentifier: String
    
    var body: some View {
        let background: Color = isGridView ? ColorProvider.BackgroundSecondary : .clear
        let size: CGFloat = isGridView ? 20 : 12
        if badges.contains(.cloud) {
            RoundIconSmall(icon: IconProvider.cloud, color: ColorProvider.TextWeak, background: background, backgroundSize: size)
                .accessibilityIdentifier("\(parentIdentifier).RoundIconSmall.cloud")
        }

        if badges.contains(.bookmark) {
            RoundIconSmall(icon: IconProvider.globe, color: ColorProvider.TextWeak)
                .accessibilityIdentifier("\(parentIdentifier).RoundIconSmall.bookmark")
        }

        if badges.contains(.sharedCollaboratively) {
            RoundIconSmall(icon: IconProvider.users, color: ColorProvider.TextWeak, background: background, backgroundSize: size)
                .accessibilityIdentifier("\(parentIdentifier).RoundIconSmall.sharedCollaboratively")
        }
        
        if badges.contains(.shared) {
            let hasSharing = featureFlagsController.hasSharing
            let icon: Image = hasSharing ? IconProvider.users : IconProvider.link
            RoundIconSmall(icon: icon, color: ColorProvider.TextWeak, background: background, backgroundSize: size)
                .accessibilityIdentifier("\(parentIdentifier).RoundIconSmall.shared")
        }
        
        if badges.contains(.offline) {
            RoundIconSmall(icon: IconProvider.arrowDownCircle, color: ColorProvider.TextWeak, background: background, backgroundSize: size)
                .accessibilityIdentifier("\(parentIdentifier).RoundIconSmall.offline")
        }
    }
}
