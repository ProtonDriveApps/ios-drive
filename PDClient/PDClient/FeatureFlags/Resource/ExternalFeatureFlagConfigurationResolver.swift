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

public struct ExternalFeatureFlagConfiguration {
    let url: URL
    let apiKey: String
    let environment: String?
    let refreshInterval: Int
}

enum ExternalFeatureFlagConfigurationResolverError: Error {
    case invalidHost
}

public protocol ExternalFeatureFlagConfigurationResolver {
    func makeConfiguration(refreshInterval: Int) throws -> ExternalFeatureFlagConfiguration
}

public final class UnleashFeatureFlagConfigurationResolver: ExternalFeatureFlagConfigurationResolver {
    private let configuration: APIService.Configuration

    public init(configuration: APIService.Configuration) {
        self.configuration = configuration
    }

    public func makeConfiguration(refreshInterval: Int) throws -> ExternalFeatureFlagConfiguration {
        let urlPath = configuration.apiOrigin + "/feature/v2/frontend" // path "/api/feature/v2/frontend" throws 404 when used with ProtonCore
        guard let url = URL(string: urlPath) else {
            throw ExternalFeatureFlagConfigurationResolverError.invalidHost
        }

        return ExternalFeatureFlagConfiguration(
            url: url,
            apiKey: "8a70ae0ecfe71c50100d667afd0ad72c079064296b92df0a4529011e",
            environment: makeEnvironment(),
            refreshInterval: refreshInterval
        )
    }

    private func makeEnvironment() -> String? {
        switch configuration.environment {
        case .black, .blackPayment:
            return "atlas-dev"
        case let .custom(scientist):
            return "atlas-\(scientist)"
        default:
            return nil
        }
    }
}
