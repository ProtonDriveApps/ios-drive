//
//  HVCommon.swift
//  ProtonCore-HumanVerification - Created on 2/1/16.
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

import Foundation
import ProtonCore_Networking
import ProtonCore_Utilities
import ProtonCore_DataModel

public final class HVCommon {

    public static func defaultSupportURL(clientApp: ClientApp) -> URL {
        switch clientApp {
        case .vpn:
            return URL(string: "https://protonvpn.com/support/protonvpn-human-verification/")!
        default:
            return URL(string: "https://proton.me/support/human-verification")!
        }
    }

    public static var bundle: Bundle {
        return Bundle(path: Bundle(for: HVCommon.self).path(forResource: "Resources-HumanVerification", ofType: "bundle")!)!
    }
}
