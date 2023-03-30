//
//  ObservabilityEnv.swift
//  ProtonCore-Observability - Created on 08.02.23.
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

import ProtonCore_Services

public struct ObservabilityEnv {
    
    public static var current = ObservabilityEnv()
    
    public static func report<Labels: Encodable & Equatable>(_ event: ObservabilityEvent<PayloadWithLabels<Labels>>) {
        ObservabilityEnv.current.observabilityService?.report(event)
    }
    
    /// The setupWorld function sets up the service used to report events before the
    /// user is logged in. Session ID is not relevant in the context of Observability.
    /// - Parameters:
    ///     - apiService: Should be the instance of the APIService used
    ///     before the user is logged in.
    public mutating func setupWorld(apiService: APIService) {
        self.observabilityService = ObservabilityServiceImpl(apiService: apiService)
    }
    
    var observabilityService: ObservabilityService?
}
