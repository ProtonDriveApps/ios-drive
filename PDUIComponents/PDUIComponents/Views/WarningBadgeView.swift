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

public enum WarningBadgeSeverance: Equatable {
    case info
    case warning
    case error
}

public struct WarningBadgeView: View {
    private let severance: WarningBadgeSeverance

    public init(severance: WarningBadgeSeverance = .error) {
        self.severance = severance
    }
    
    public var body: some View {
        IconProvider.exclamationCircleFilled
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(color)
    }

    private var color: Color {
        switch severance {
        case .info:
            return Color.IconWeak
        case .warning:
            return Color.NotificationWarning
        case .error:
            return Color.NotificationError
        }
    }
}
