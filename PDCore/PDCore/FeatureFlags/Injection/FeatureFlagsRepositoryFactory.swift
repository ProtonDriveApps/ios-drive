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
#if canImport(UIKit)
import UIKit
#endif
import PDClient
import UnleashProxyClientSwift

struct FeatureFlagsRepositoryFactory {
    
    private func makeExternalResource(configuration: APIService.Configuration, networking: CoreAPIService) -> ExternalFeatureFlagsResource {
        let session = UnleashPollerSession(networking: networking)
        let configurationResolver = UnleashFeatureFlagConfigurationResolver(configuration: configuration)

        let resource = UnleashFeatureFlagsResource(
            refreshInterval: getRefreshInterval(),
            session: session,
            configurationResolver: configurationResolver,
            logMessageHandler: { Log.info($0, domain: .featureFlags) },
            logErrorHandler: {
                if case .noResponse = $0 as? PollerError {
                    // a no connection error, we can treat that as info
                    Log.info($0.localizedDescription, domain: .featureFlags)
                } else {
                    Log.error($0.localizedDescription, domain: .featureFlags)
                }
            }
        )
        
        #if os(iOS)
        let didBecomeActiveNotificationName = UIApplication.didBecomeActiveNotification
        let didBecomeActivePublisher = NotificationCenter.default
            .publisher(for: didBecomeActiveNotificationName)
            .map { _ in () }
            .eraseToAnyPublisher()
        resource.forceUpdate(on: didBecomeActivePublisher)
        #endif
        
        return resource
    }

    private func getRefreshInterval() -> Int {
        if Constants.buildType.isQaOrBelow {
            return 5 * 60 // 5 min
        } else {
            return 10 * 60 // 10 min
        }
    }

    func makeRepository(configuration: APIService.Configuration, networking: CoreAPIService, store: ExternalFeatureFlagsStore) -> FeatureFlagsRepository {
        let externalResource = makeExternalResource(configuration: configuration, networking: networking)
        return ExternalFeatureFlagsRepository(externalResource: externalResource, externalStore: store)
    }
}
