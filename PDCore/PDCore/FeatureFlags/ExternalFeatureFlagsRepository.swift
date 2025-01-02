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
    private var firstUpdateCancellable: AnyCancellable?
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
                Log.info("⛳️ FeatureFlag: \(storageFlag) value: \(value)", domain: .featureFlags)
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
            // We need to handle just first callback (either error or update) and make sure not to call
            // continuation multiple times.
            // The `completionBlock` from `externalResource` can be called multiple times, it's design of 3rd party
            // library.
            var continuation: CheckedContinuation<Void, any Error>? = continuation
            firstUpdateCancellable = updatePublisher
                .first()
                .sink(receiveValue: { _ in
                    continuation?.resume()
                    continuation = nil
                })
            externalResource.start { error in
                if let error {
                    self.firstUpdateCancellable = nil
                    continuation?.resume(throwing: error)
                    continuation = nil
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

    // swiftlint:disable:next cyclomatic_complexity
    func mapExternalFeatureFlagToAvailability(external: ExternalFeatureFlag) -> FeatureAvailabilityFlag {
        switch external {
        case .photosUploadDisabled: return .photosUploadDisabled
        case .logsCompressionDisabled: return .logsCompressionDisabled
        case .postMigrationJunkFilesCleanup: return .postMigrationJunkFilesCleanup
        case .domainReconnectionEnabled: return .domainReconnectionEnabled
        case .newTrayAppMenuEnabled: return .newTrayAppMenuEnabled
        case .pushNotificationIsEnabled: return .pushNotificationIsEnabled
        case .logCollectionEnabled: return .logCollectionEnabled
        case .logCollectionDisabled: return .logCollectionDisabled
        case .oneDollarPlanUpsellEnabled: return .oneDollarPlanUpsellEnabled
        case .driveDisablePhotosForB2B: return .driveDisablePhotosForB2B
        case .driveDDKEnabled: return .driveDDKEnabled
        // Sharing
        case .driveSharingMigration: return .driveSharingMigration
        case .driveiOSSharing: return .driveiOSSharing
        case .driveSharingDevelopment: return .driveSharingDevelopment
        case .driveSharingInvitations: return .driveSharingInvitations
        case .driveSharingExternalInvitations: return .driveSharingExternalInvitations
        case .driveSharingDisabled: return .driveSharingDisabled
        case .driveSharingExternalInvitationsDisabled: return .driveSharingExternalInvitationsDisabled
        case .driveSharingEditingDisabled: return .driveSharingEditingDisabled
        case .drivePublicShareEditMode: return .drivePublicShareEditMode
        case .drivePublicShareEditModeDisabled: return .drivePublicShareEditModeDisabled
        // ProtonDoc
        case .driveDocsWebView: return .driveDocsWebView
        case .driveDocsDisabled: return .driveDocsDisabled
        // Entitlement
        case .driveDynamicEntitlementConfiguration: return .driveDynamicEntitlementConfiguration
        }
    }
}
