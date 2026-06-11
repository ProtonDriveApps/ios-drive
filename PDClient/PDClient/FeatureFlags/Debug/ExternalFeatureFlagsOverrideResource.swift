// Copyright (c) 2025 Proton AG
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

#if DEBUG
import Combine

public final class ExternalFeatureFlagsOverrideResource: ExternalFeatureFlagsResource {
    public var updatePublisher: AnyPublisher<Void, Never> {
        wrappedResource.updatePublisher
    }
    
    private let wrappedResource: ExternalFeatureFlagsResource
    private let overrides: [ExternalFeatureFlagOverride]

    public init(wrappedResource: ExternalFeatureFlagsResource, overrides: [ExternalFeatureFlagOverride]) {
        self.wrappedResource = wrappedResource
        self.overrides = overrides
    }

    public func start(completionHandler: @escaping ((any Error)?) -> Void) {
        wrappedResource.start(completionHandler: completionHandler)
    }

    public func stop() {
        wrappedResource.stop()
    }

    public func isEnabled(flag: ExternalFeatureFlag) -> Bool {
        if let overridenValue = overrides.first(where: { $0.flag == flag }) {
            return overridenValue.value
        }

        // By default all killswitches are turned off in Debug builds
        // Similarly all rollout flags are turned on in Debug builds
        // In case that more precision is needed, this is the place to add a condition
        if flag.rawValue.hasSuffix("Disabled") {
            return false
        } else {
            return true
        }
    }
}
#endif
