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

import Combine
import CoreData
import PDCore
import PDCoreIOS
import PDContacts
import PDUIComponents
import ProtonCoreKeymaker
import ProtonCoreServices
import UIKit

// Main photos container. See `README.md` for more info.
public final class PDPhotosContainer {
    let dependencies: Dependencies
    lazy var rootViewModel: RootViewModel = PDPhotosFactory().makeRootViewModel()
    lazy var sceneContainer = PhotosScenesContainer(parent: self)
    public lazy var migrationController: PhotoVolumeMigrationControllerProtocol = makeMigrationController()
    lazy var bootstrapController: PhotoVolumeBootstrapControllerProtocol = makeBootstrapController()
    lazy var migrationAvailableController = makeMigrationSheetAvailableController()

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeRootViewController(configuration: PhotosRootConfiguration) -> UIViewController {
        return PhotosRootFactory().makeViewController(container: self, configuration: configuration)
    }

    public func makeBackupStartController() -> PhotosBackupStartController {
        PhotosBackupStartFactory().makeController(
            settingsController: dependencies.settingsController,
            authorizationController: dependencies.authorizationController,
            volumeBootstrapController: bootstrapController
        )
    }
}

// MARK: - Factory
extension PDPhotosContainer {
    private func makeBootstrapController() -> PhotoVolumeBootstrapControllerProtocol {
        PDPhotosFactory().makeBootstrapController(
            migrationController: migrationController,
            tower: dependencies.tower,
            featureFlagsController: dependencies.featureFlagsController,
            shareCreationResource: dependencies.shareCreationResource,
            errorController: dependencies.legacyShareErrorController
        )
    }

    private func makeMigrationSheetAvailableController() -> MigrationSheetAvailableControllerProtocol {
        PDPhotosFactory().makeMigrationSheetAvailableController(tower: dependencies.tower)
    }

    private func makeMigrationController() -> PhotoVolumeMigrationControllerProtocol {
        PDPhotosFactory().makeMigrationController(tower: dependencies.tower)
    }
}

public extension PDPhotosContainer {
    struct Dependencies {
        let tower: Tower
        let keymaker: Keymaker
        let networkService: PMAPIService
        let settingsController: PhotoBackupSettingsController
        let authorizationController: PhotoLibraryAuthorizationController
        let backupProgressController: PhotosBackupProgressController
        let processingController: PhotosProcessingController
        let uploader: PhotoUploader
        let quotaStateController: QuotaStateController
        let lockBannerRepository: ScreenLockingBannerRepository
        let failedPhotosResource: DeletedPhotosIdentifierStoreResource
        let backupStateController: PhotosBackupStateController
        let retryTriggerController: PhotoLibraryLoadRetryTriggerController
        let constraintsController: PhotoBackupConstraintsController
        let photoSharesObserver: FetchedResultsControllerObserver<PDCore.Share>
        let notificationsPermissionsFlowController: NotificationsPermissionsFlowController
        let photoUpsellResultNotifier: PhotoUpsellResultNotifierProtocol
        let photosManagedObjectContext: NSManagedObjectContext
        let photoUploadedNotifier: PhotoUploadedNotifier
        let contactsManager: ContactsManagerProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let rootFolderRepository: PhotosRootFolderRepository
        let scrollToTopPublisher: AnyPublisher<TabBarItem, Never>
        let userMessageHandler: UserMessageHandlerProtocol
        let sharingMemberFactory: SharingMemberStartFactoryProtocol
        let legacyBootstrapController: PhotosBootstrapController
        let shareCreationResource: PhotoShareCreationFinishResource
        let legacyShareErrorController: ErrorSetControllerProtocol
        let photoTagsMigrationController: PhotoTagsMigrationController
        let tagsMigrationConstraint: MigrationConstraintController

        public init(
            tower: Tower,
            keymaker: Keymaker,
            networkService: PMAPIService,
            settingsController: PhotoBackupSettingsController,
            authorizationController: PhotoLibraryAuthorizationController,
            backupProgressController: PhotosBackupProgressController,
            processingController: PhotosProcessingController,
            uploader: PhotoUploader,
            quotaStateController: QuotaStateController,
            lockBannerRepository: ScreenLockingBannerRepository,
            failedPhotosResource: DeletedPhotosIdentifierStoreResource,
            backupStateController: PhotosBackupStateController,
            retryTriggerController: PhotoLibraryLoadRetryTriggerController,
            constraintsController: PhotoBackupConstraintsController,
            photoSharesObserver: FetchedResultsControllerObserver<PDCore.Share>,
            notificationsPermissionsFlowController: NotificationsPermissionsFlowController,
            photoUpsellResultNotifier: PhotoUpsellResultNotifierProtocol,
            photosManagedObjectContext: NSManagedObjectContext,
            photoUploadedNotifier: PhotoUploadedNotifier,
            contactsManager: ContactsManagerProtocol,
            featureFlagsController: FeatureFlagsControllerProtocol,
            rootFolderRepository: PhotosRootFolderRepository,
            scrollToTopPublisher: AnyPublisher<TabBarItem, Never>,
            userMessageHandler: UserMessageHandlerProtocol,
            sharingMemberFactory: SharingMemberStartFactoryProtocol,
            legacyBootstrapController: PhotosBootstrapController,
            shareCreationResource: PhotoShareCreationFinishResource,
            legacyShareErrorController: ErrorSetControllerProtocol,
            photoTagsMigrationController: PhotoTagsMigrationController,
            tagsMigrationConstraint: MigrationConstraintController
        ) {
            self.tower = tower
            self.keymaker = keymaker
            self.networkService = networkService
            self.settingsController = settingsController
            self.authorizationController = authorizationController
            self.backupProgressController = backupProgressController
            self.processingController = processingController
            self.uploader = uploader
            self.quotaStateController = quotaStateController
            self.lockBannerRepository = lockBannerRepository
            self.failedPhotosResource = failedPhotosResource
            self.backupStateController = backupStateController
            self.retryTriggerController = retryTriggerController
            self.constraintsController = constraintsController
            self.photoSharesObserver = photoSharesObserver
            self.notificationsPermissionsFlowController = notificationsPermissionsFlowController
            self.photoUpsellResultNotifier = photoUpsellResultNotifier
            self.photosManagedObjectContext = photosManagedObjectContext
            self.photoUploadedNotifier = photoUploadedNotifier
            self.contactsManager = contactsManager
            self.featureFlagsController = featureFlagsController
            self.rootFolderRepository = rootFolderRepository
            self.scrollToTopPublisher = scrollToTopPublisher
            self.userMessageHandler = userMessageHandler
            self.sharingMemberFactory = sharingMemberFactory
            self.legacyBootstrapController = legacyBootstrapController
            self.shareCreationResource = shareCreationResource
            self.legacyShareErrorController = legacyShareErrorController
            self.photoTagsMigrationController = photoTagsMigrationController
            self.tagsMigrationConstraint = tagsMigrationConstraint
        }
    }
}
