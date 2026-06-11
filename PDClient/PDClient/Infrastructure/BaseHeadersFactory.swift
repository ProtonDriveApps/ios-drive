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

import Foundation

public protocol BaseHeadersFactory {
    func makeHeaders() -> [String: String]
}

public final class DriveBaseHeadersFactory: BaseHeadersFactory {
    private let configuration: APIService.Configuration
    private let featureFlags: ExternalFeatureFlagsResource?

    public init(configuration: APIService.Configuration, featureFlags: ExternalFeatureFlagsResource? = nil) {
        self.configuration = configuration
        self.featureFlags = featureFlags
    }

    public func makeHeaders() -> [String: String] {
        var headers = [
            "x-pm-appversion": configuration.clientVersion,
            "Accept": "application/vnd.protonmail.v1+json",
            "Content-Type": "application/json;charset=utf-8"
        ]
        if let features = getCoreClientFeatures() {
            headers["x-pm-client-features"] = features
        }
        return headers
    }

    private func getCoreClientFeatures() -> String? {
        let features = [
            isPaymentsV2Enabled() ? "Drive.DriveiOSPaymentsV2" : nil
        ].compactMap { $0 }

        guard !features.isEmpty else {
            return nil
        }
        return features.joined(separator: ",")
    }

    private func isPaymentsV2Enabled() -> Bool {
        #if os(iOS)
        return featureFlags?.isEnabled(flag: .driveiOSPaymentsV2) ?? false
        #else
        return false
        #endif
    }
}
