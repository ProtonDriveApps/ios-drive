//
//  AuthModulusResponse.swift
//  ProtonCore-APIClient - Created on 25.04.23.
//
//  Copyright (c) 2023 Proton Technologies AG
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
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore. If not, see https://www.gnu.org/licenses/.
//

import ProtonCoreNetworking

public final class AuthModulusResponse: Response, Codable {

    public var modulus: String?
    public var modulusID: String?

    override public func ParseResponse(_ response: [String: Any]!) -> Bool {
        self.modulus = response["Modulus"] as? String
        self.modulusID = response["ModulusID"] as? String
        return true
    }

    required init() {}
}
