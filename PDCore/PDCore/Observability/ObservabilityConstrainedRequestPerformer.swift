// Copyright (c) 2026 Proton AG
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

import Foundation
import ProtonCoreNetworking
import ProtonCoreServices

public final class ObservabilityConstrainedRequestPerformer: RequestPerforming {
    private let localSettings: LocalSettings
    private let requestPerforming: RequestPerforming

    public init(localSettings: LocalSettings, requestPerforming: RequestPerforming) {
        self.localSettings = localSettings
        self.requestPerforming = requestPerforming
    }

    public func performRequest(
        request: any Request,
        parameters: Any?,
        headers: [String : Any]?,
        onDataTaskCreated: @escaping (URLSessionDataTask) -> Void,
        jsonCompletion: JSONCompletion?
    ) {
        let isOptedOut = localSettings.optOutFromTelemetry ?? false // Default is not opted out
        guard !isOptedOut else {
            return
        }

        requestPerforming.performRequest(
            request: request,
            parameters: parameters,
            headers: headers,
            onDataTaskCreated: onDataTaskCreated,
            jsonCompletion: jsonCompletion
        )
    }
}
