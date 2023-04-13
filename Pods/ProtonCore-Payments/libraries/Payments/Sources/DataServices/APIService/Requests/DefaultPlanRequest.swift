//
//  DefaultPlanRequest.swift
//  ProtonCore-Payments - Created on 2/12/2020.
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
import ProtonCore_Log
import ProtonCore_Networking
import ProtonCore_Services

public final class DefaultPlanRequest: BaseApiRequest<DefaultPlanResponse> {

    override public init(api: APIService) {
        super.init(api: api)
    }
    
    override public var path: String { super.path + "/v4/plans/default" }

    override public var isAuth: Bool { false }
}

public final class DefaultPlanResponse: Response {

    private(set) var defaultServicePlanDetails: Plan?

    override public func ParseResponse(_ response: [String: Any]!) -> Bool {
        PMLog.debug(response.json(prettyPrinted: true))
        guard let plansResponse = response["Plans"] else { return false }
        let (result, details) = decodeResponse(plansResponse, to: Plan.self, errorToReturn: .defaultPlanDecode)
        defaultServicePlanDetails = details
        return result
    }
}
