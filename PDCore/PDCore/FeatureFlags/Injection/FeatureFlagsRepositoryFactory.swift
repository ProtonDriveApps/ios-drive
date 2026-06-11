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
    
    private func makeExternalResource(
        configuration: APIService.Configuration,
        networking: CoreAPIService,
        overrides: [ExternalFeatureFlagOverride]
    ) -> ExternalFeatureFlagsResource {
        let session = UnleashPollerSession(networking: networking)
        let configurationResolver = UnleashFeatureFlagConfigurationResolver(configuration: configuration)

        let resource = UnleashFeatureFlagsResource(
            refreshInterval: getRefreshInterval(),
            session: session,
            configurationResolver: configurationResolver
        )
        
        #if os(iOS)
        let didBecomeActiveNotificationName = UIApplication.didBecomeActiveNotification
        let didBecomeActivePublisher = NotificationCenter.default
            .publisher(for: didBecomeActiveNotificationName)
            .map { _ in () }
            .eraseToAnyPublisher()
        resource.forceUpdate(on: didBecomeActivePublisher)
        #endif

        #if DEBUG && os(iOS)
        return ExternalFeatureFlagsOverrideResource(wrappedResource: resource, overrides: overrides)
        #else
        return resource
        #endif
    }

    private func getFeatureFlagsOverrides() -> [ExternalFeatureFlagOverride] {
#if DEBUG
        if DebugConstants.commandLineContains(flags: [.uiTests]) {
            let commandLine = DebugConstants.getValueOf(flag: .featureFlagsOverrides) ?? ""
            return ExternalFeatureFlagOverrideCommandLineSerializer().deserialize(from: commandLine)
        } else {
            return []
        }
#endif
        return []
    }

    private func makeLegacyResource(
        configuration: APIService.Configuration,
        networking: CoreAPIService
    ) -> ExternalFeatureFlagsResource {
        let resource = LegacyFeatureFlagsResource(
            configuration: configuration,
            networking: networking,
            refreshInterval: TimeInterval(getRefreshInterval())
        )
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
        let overrideFlags = getFeatureFlagsOverrides()
        let externalResource = makeExternalResource(
            configuration: configuration,
            networking: networking,
            overrides: overrideFlags
        )
        let legacyResource = makeLegacyResource(configuration: configuration, networking: networking)

        let repository = ExternalFeatureFlagsRepository(
            externalResource: externalResource,
            legacyResource: legacyResource,
            externalStore: store
        )
        override(flags: overrideFlags, to: store, repository: repository)
        return repository
    }

    private func override(
        flags: [ExternalFeatureFlagOverride],
        to store: ExternalFeatureFlagsStore,
        repository: ExternalFeatureFlagsRepository
    ) {
        #if DEBUG
        for flag in flags {
            let mappedFlag = repository.mapExternalFeatureFlagToAvailability(external: flag.flag)
            store.setFeatureEnabled(mappedFlag, value: flag.value)
        }
        #endif
    }
}
