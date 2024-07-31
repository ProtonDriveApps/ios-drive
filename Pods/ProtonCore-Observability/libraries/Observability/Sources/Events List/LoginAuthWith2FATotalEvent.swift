//
//  LoginAuthWith2FATotalEvent.swift
//  ProtonCore-Observability - Created on 10.06.2024.
//
//  Copyright (c) 2024 Proton Technologies AG
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

import ProtonCoreNetworking

public struct LoginAuthWith2FALabels: Encodable, Equatable {
    let status: HTTPResponseCodeStatus
    let twoFAType: TwoFAType

    enum CodingKeys: String, CodingKey {
        case status
        case twoFAType
    }
}

extension ObservabilityEvent where Payload ==  PayloadWithLabels<LoginAuthWith2FALabels> {
    public static func loginAuthWith2FATotalEvent(status: HTTPResponseCodeStatus,
                                                  twoFAType type: TwoFAType) -> Self {
        .init(name: "ios_core_login_2fa_auth_total",
              labels: .init(status: status, twoFAType: type))
    }
}

