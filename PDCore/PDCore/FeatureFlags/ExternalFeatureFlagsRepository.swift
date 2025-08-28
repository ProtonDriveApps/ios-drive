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
    private let legacyResource: ExternalFeatureFlagsResource
    private let externalStore: ExternalFeatureFlagsStore
    private var cancellables = Set<AnyCancellable>()
    private var firstUpdateCancellable: AnyCancellable?
    private var subject = PassthroughSubject<Void, Never>()
    private var isExternalInitialized = false
    private var isLegacyInitialized = false

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    init(
        externalResource: ExternalFeatureFlagsResource,
        legacyResource: ExternalFeatureFlagsResource,
        externalStore: ExternalFeatureFlagsStore
    ) {
        self.externalResource = externalResource
        self.externalStore = externalStore
        self.legacyResource = legacyResource

        setupStoreUpdates()
    }
    
    func setupStoreUpdates() {
        externalResource.updatePublisher
            .combineLatest(legacyResource.updatePublisher)
            .sink { [weak self] _, _ in
                guard let self = self else { return }

                var messages: [String] = ["⛳️ FeatureFlag updated"]
                for externalFlag in ExternalFeatureFlag.allCases {
                    let storageFlag = self.mapExternalFeatureFlagToAvailability(external: externalFlag)
                    let value: Bool
                    if externalFlag == .ratingIOSDrive {
                        value = self.legacyResource.isEnabled(flag: externalFlag)
                    } else {
                        value = self.externalResource.isEnabled(flag: externalFlag)
                    }
                    messages.append("Flag: \(storageFlag) value: \(value)")
                    self.externalStore.setFeatureEnabled(storageFlag, value: value)
                }
                Log.info(messages.joined(separator: "\n"), domain: .featureFlags)
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

            start { error in
                if let error {
                    self.firstUpdateCancellable = nil
                    continuation?.resume(throwing: error)
                    continuation = nil
                }
            }
        }
    }

    func start(completionHandler: @escaping (Error?) -> Void) {
        let group = DispatchGroup()
        var observedError: Error?
        group.enter()
        legacyResource.start { error in
            if let error {
                observedError = error
            }
            group.leave()
        }
        
        group.enter()
        externalResource.start { error in
            if let error {
                observedError = error
            }
            group.leave()
        }
        
        group.notify(queue: DispatchQueue.global()) {
            completionHandler(observedError)
        }
    }

    func stop() {
        externalResource.stop()
        legacyResource.stop()
    }

    // swiftlint:disable:next cyclomatic_complexity
    func mapExternalFeatureFlagToAvailability(external: ExternalFeatureFlag) -> FeatureAvailabilityFlag {
        switch external {
        case .photosUploadDisabled: return .photosUploadDisabled
        case .logsCompressionDisabled: return .logsCompressionDisabled
        case .postMigrationJunkFilesCleanup: return .postMigrationJunkFilesCleanup
        case .domainReconnectionEnabled: return .domainReconnectionEnabled
        case .pushNotificationIsEnabled: return .pushNotificationIsEnabled
        case .logCollectionEnabled: return .logCollectionEnabled
        case .logCollectionDisabled: return .logCollectionDisabled
        case .oneDollarPlanUpsellEnabled: return .oneDollarPlanUpsellEnabled
        case .driveDisablePhotosForB2B: return .driveDisablePhotosForB2B
        case .driveDDKEnabled: return .driveDDKEnabled
        case .driveMacSyncRecoveryDisabled: return .driveMacSyncRecoveryDisabled
        case .driveMacKeepDownloadedDisabled: return .driveMacKeepDownloadedDisabled
        // Sharing
        case .driveSharingMigration: return .driveSharingMigration
        case .driveSharingInvitations: return .driveSharingInvitations
        case .driveSharingExternalInvitations: return .driveSharingExternalInvitations
        case .driveSharingDisabled: return .driveSharingDisabled
        case .driveSharingExternalInvitationsDisabled: return .driveSharingExternalInvitationsDisabled
        case .driveSharingEditingDisabled: return .driveSharingEditingDisabled
        case .drivePublicShareEditMode: return .drivePublicShareEditMode
        case .drivePublicShareEditModeDisabled: return .drivePublicShareEditModeDisabled
        case .acceptRejectInvitation: return .driveMobileSharingInvitationsAcceptReject
        case .driveShareURLBookmarking: return .driveShareURLBookmarking
        case .driveShareURLBookmarksDisabled: return.driveShareURLBookmarksDisabled
        // ProtonDoc
        case .driveDocsDisabled: return .driveDocsDisabled
        // Rating booster
        // Legacy feature flags we used before migrating to Unleash
        case .ratingIOSDrive: return .ratingIOSDrive
        case .driveRatingBooster: return .driveRatingBooster
        // Entitlement
        case .driveDynamicEntitlementConfiguration: return .driveDynamicEntitlementConfiguration
        // Refactor
        case .driveiOSRefreshableBlockDownloadLink: return .driveiOSRefreshableBlockDownloadLink
        // Computers
        case .driveiOSComputers: return .driveiOSComputers
        case .driveiOSComputersDisabled: return .driveiOSComputersDisabled
        // Album
        case .driveAlbumsDisabled: return .driveAlbumsDisabled
        case .driveCopyDisabled: return .driveCopyDisabled
        case .drivePhotosTagsMigration: return .drivePhotosTagsMigration
        case .drivePhotosTagsMigrationDisabled: return .drivePhotosTagsMigrationDisabled
        // Sheets
        case .docsSheetsEnabled: return .docsSheetsEnabled
        case .docsSheetsDisabled: return .docsSheetsDisabled
        case .docsCreateNewSheetOnMobileEnabled: return .docsCreateNewSheetOnMobileEnabled
        case .driveiOSDebugMode: return .driveiOSDebugMode
        }
    }
}
