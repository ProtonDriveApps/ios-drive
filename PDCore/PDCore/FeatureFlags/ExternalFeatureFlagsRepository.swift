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
import Combine
import PDClient

class ExternalFeatureFlagsRepository: FeatureFlagsRepository {
    private let externalResource: ExternalFeatureFlagsResource
    private let externalStore: ExternalFeatureFlagsStore
    private var cancellables = Set<AnyCancellable>()
    private var subject = PassthroughSubject<Void, Never>()

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    init(externalResource: ExternalFeatureFlagsResource, externalStore: ExternalFeatureFlagsStore) {
        self.externalResource = externalResource
        self.externalStore = externalStore

        setupStoreUpdates()
    }

    func setupStoreUpdates() {
        externalResource.updatePublisher
        .sink { [weak self] _ in
            guard let self = self else { return }

            for externalFlag in ExternalFeatureFlag.allCases {
                let storageFlag = self.mapExternalFeatureFlagToAvailability(external: externalFlag)
                let value = self.externalResource.isEnabled(flag: externalFlag)
                self.externalStore.setFeatureEnabled(storageFlag, value: value)
            }
            self.subject.send()
        }
        .store(in: &cancellables)
    }

    public func isEnabled(flag: FeatureAvailabilityFlag) -> Bool {
        externalStore.isFeatureEnabled(flag)
    }

    public func enable(flag: FeatureAvailabilityFlag) {
        externalStore.setFeatureEnabled(flag, value: true)
    }

    public func disable(flag: FeatureAvailabilityFlag) {
        externalStore.setFeatureEnabled(flag, value: false)
    }

    func startAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            externalResource.start { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func start(completionHandler: @escaping (Error?) -> Void) {
        externalResource.start(completionHandler: completionHandler)
    }

    func stop() {
        externalResource.stop()
    }

    func mapExternalFeatureFlagToAvailability(external: ExternalFeatureFlag) -> FeatureAvailabilityFlag {
        switch external {
        case .photosEnabled: return .photosEnabled
        case .photosUploadDisabled: return .photosUploadDisabled
        case .photosBackgroundSyncEnabled: return .photosBackgroundSyncEnabled
        case .logsCompressionDisabled: return .logsCompressionDisabled
        case .postMigrationJunkFilesCleanup: return .postMigrationJunkFilesCleanup
        case .domainReconnectionEnabled: return .domainReconnectionEnabled
        case .newTrayAppMenuEnabled: return .newTrayAppMenuEnabled
        case .logCollectionEnabled: return .logCollectionEnabled
        case .logCollectionDisabled: return .logCollectionDisabled
        }
    }
}
