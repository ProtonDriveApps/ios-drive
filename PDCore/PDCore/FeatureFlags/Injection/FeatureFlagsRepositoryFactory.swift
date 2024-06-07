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
import PDClient
import UnleashProxyClientSwift

struct FeatureFlagsRepositoryFactory {
    
    private func makeExternalResource(configuration: APIService.Configuration, networking: CoreAPIService) -> ExternalFeatureFlagsResource {
        let session = UnleashPollerSession(networking: networking)
        let configurationResolver = UnleashFeatureFlagConfigurationResolver(configuration: configuration)
        
        #if HAS_QA_FEATURES
        let unleashRefreshInterval = 5 * 60 // 5 min
        #else
        let unleashRefreshInterval = 10 * 60 // 10 min
        #endif
        
        let resource = UnleashFeatureFlagsResource(
            refreshInterval: unleashRefreshInterval,
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
    
    func makeRepository(configuration: APIService.Configuration, networking: CoreAPIService, store: ExternalFeatureFlagsStore) -> FeatureFlagsRepository {
        let externalResource = makeExternalResource(configuration: configuration, networking: networking)
        return ExternalFeatureFlagsRepository(externalResource: externalResource, externalStore: store)
    }
}
