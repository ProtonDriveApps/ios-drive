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

import ProtonCoreLoginUI

public enum DriveCoreAlert: Equatable {
    case logout
    case trustKitFailure
    case trustKitHardFailure
    case humanVerification
    case forceUpgrade
    case userGoneDelinquent

    public var title: String {
        switch self {
        case .logout:
            return "Logged out"
        case .trustKitFailure:
            return "Insecure connection"
        case .trustKitHardFailure:
            return "Insecure connection"
        case .humanVerification:
            fatalError("Should be handled by ProtonCore")
        case .forceUpgrade:
            return "Force Upgrade"
        case .userGoneDelinquent:
            return "Overdue Invoice"
        }
    }

    public var message: String {
        switch self {
        case .logout:
            return LUITranslation.info_session_expired.l10n
        case .trustKitFailure:
            return "TLS certificate validation failed. Your connection may be monitored and the app is temporarily blocked for your safety.\n\nswitch  networks immediately"
        case .trustKitHardFailure:
            return "TLS certificate validation failed. Your connection may be monitored and the app is temporarily blocked for your safety.\n\n"
        case .humanVerification:
            fatalError("Should be handled by ProtonCore")
        case .forceUpgrade:
            return "You are using an outdated version of the app which is no longer supported by our servers. Please update the app."
        case .userGoneDelinquent:
            return "Your Proton account is currently on hold. To continue using your account, please pay any overdue invoices"
        }
    }
}

public struct AlertAction: Equatable {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    public static func == (lhs: AlertAction, rhs: AlertAction) -> Bool {
        lhs.title == rhs.title
    }
}
