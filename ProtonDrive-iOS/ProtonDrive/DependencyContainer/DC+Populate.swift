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

import UIKit
import PDCore
import PDCoreIOS
import Combine
import ProtonCoreAuthentication
import ProtonCoreFeatureFlags
import ProtonCoreHumanVerification
import ProtonCoreKeymaker
import ProtonCoreServices
import UserNotifications
import SwiftUI
import PDUIComponents
import PDContacts
import PMEventsManager
import PDSDKCore

final class AuthenticatedDependencyContainer {
    let tower: Tower
    let keymaker: Keymaker
    let networkService: PMAPIService
    let localSettings: LocalSettings
    private var applicationStateController: ApplicationStateOperationsController?
    let extensionTaskStateController: ConcreteBackgroundTaskStateController
    var childContainers: [Any]
    var humanCheckHelper: HumanCheckHelper?
    let pickersContainer: PickersContainer
    let photosContainer: PhotosContainer
    let protonFileContainer: ProtonFilePreviewContainer
    let featureFlagsController: FeatureFlagsControllerProtocol
    let authenticator: Authenticator
    let contactsManager: ContactsManagerProtocol
    let sharedVolumesEventsContainer: SharedVolumesEventsContainer
    let populatedStateController: PopulatedStateControllerProtocol
    let contactEventBridge: ContactUpdateDelegate
    let ratingBoosterFlowController: RatingBoosterFlowControllerProtocol
    let applicationUserSettingsController: ApplicationUserSettingsController
    let photosSkippableCacheStorage: PhotosSkippableStorage
    let scrollToTopSubject = PassthroughSubject<TabBarItem, Never>()
    private weak var autoLocker: Autolocker?
    let lockedStateController: LockedStateControllerProtocol
    let volumeLockController: VolumeLockController
    private var bootstrappedSubject = CurrentValueSubject<Bool, Never>(false)
    let bootstrapStateController: BootstrapStateControllerProtocol
    let sceneInitStateController: SceneInitStateControllerProtocol
    private let duplicateUploadHandler: DuplicateUploadHandler

    @MainActor
    init(
        tower: Tower,
        keymaker: Keymaker,
        networkService: PMAPIService,
        localSettings: LocalSettings,
        settingsSuite: SettingsStorageSuite,
        authenticator: Authenticator,
        populatedStateController: PopulatedStateControllerProtocol,
        autoLocker: Autolocker?,
        featureFlagsController: FeatureFlagsControllerProtocol,
        bootstrapStateController: BootstrapStateControllerProtocol = BootstrapStateController(),
        sceneInitStateController: SceneInitStateControllerProtocol = SceneInitStateController(),
        photoUploadedNotifier: PhotoUploadedNotifier,
        failedPhotosResource: DeletedPhotosIdentifierStoreResource,
        photosSkippableCacheStorage: PhotosSkippableStorage,
        lockedStateController: LockedStateControllerProtocol,
        volumeLockController: VolumeLockController
    ) {
        self.tower = tower
        self.keymaker = keymaker
        self.networkService = networkService
        self.localSettings = localSettings
        self.authenticator = authenticator
        self.contactsManager = ContactsManager(
            service: networkService,
            log: { desc in Log.info(desc, domain: .contact) },
            error: { desc in Log.error(desc, error: nil, domain: .contact) }
        )
        self.populatedStateController = populatedStateController
        self.autoLocker = autoLocker
        self.bootstrapStateController = bootstrapStateController
        self.sceneInitStateController = sceneInitStateController
        contactEventBridge = ContactEventBridge(contactsManager: contactsManager)
        tower.contactAdapter.delegate = contactEventBridge
        let converter = ExternalInvitationConverter(
            client: tower.client,
            contactsManager: contactsManager,
            inviteHandler: InternalUserInviteInteractor(client: tower.client, encryptionResource: Encryptor()),
            signersFactory: tower.sessionVault
        )
        tower.set(externalInvitationConverter: converter)
        self.lockedStateController = lockedStateController
        self.volumeLockController = volumeLockController

        pickersContainer = PickersContainer()

        extensionTaskStateController = ConcreteBackgroundTaskStateController()

        self.photosSkippableCacheStorage = photosSkippableCacheStorage
        self.featureFlagsController = featureFlagsController
        let notificationFlowController = NotificationsPermissionsFactory().makeFlowController()
        ratingBoosterFlowController = RatingBoosterFlowController(
            coordinator: RatingBoosterCoordinator(
                bugReportFactory: BugReportFactory(apiService: tower.networking, sessionVault: tower.sessionVault)
            ),
            featureFlagsController: featureFlagsController,
            localSettings: localSettings,
            repository: DisableLegacyRatingRepository(networkService: tower.networking)
        )

        assert(tower.performanceMetricsController != nil)
        let dependencies = PhotosContainer.Dependencies(
            tower: tower,
            keymaker: keymaker,
            networkService: networkService,
            settingsSuite: settingsSuite,
            extensionStateController: extensionTaskStateController,
            photoSkippableCache: ConcretePhotosSkippableCache(storage: photosSkippableCacheStorage),
            notificationsPermissionsFlowController: notificationFlowController,
            contacstsManager: contactsManager,
            featureFlagsController: featureFlagsController,
            populatedStateController: populatedStateController,
            scrollToTopPublisher: scrollToTopSubject.eraseToAnyPublisher(),
            lockedStateController: lockedStateController,
            performanceMetricsController: tower.performanceMetricsController ?? PerformanceMetricsController(),
            authenticator: authenticator,
            bootstrapStateController: bootstrapStateController,
            photoUploadedNotifier: photoUploadedNotifier,
            failedPhotosResource: failedPhotosResource
        )
        photosContainer = PhotosContainer(dependencies: dependencies)

        // Child containers
        childContainers = [
            LocalNotificationsContainer(tower: tower),
            MyFilesNotificationsPermissionsContainer(tower: tower, flowController: notificationFlowController),
            ForegroundTransitionContainer(
                tower: tower,
                pickerResource: pickersContainer.photoPickerResource,
                populatedStateController: populatedStateController,
                lockedStateController: lockedStateController,
                volumeLockController: volumeLockController
            ),
            QuotaUpdatesContainer(tower: tower, photoUploader: tower.sdkObjects.photoUploader),
            PaymentsCleanUpContainer(tower: tower),
        ]

        protonFileContainer = ProtonFilePreviewContainer(
            dependencies: .init(
                tower: tower,
                featureFlagsController: featureFlagsController,
                apiService: networkService,
                authenticator: authenticator
            )
        )
        sharedVolumesEventsContainer = SharedVolumesEventsContainer(tower: tower, featureFlagsController: featureFlagsController)
        applicationUserSettingsController = ApplicationUserSettingsController(localSettings: localSettings, notificationCenter: .default)
        duplicateUploadHandler = DuplicateUploadHandler(dependencies: .init(
            bootstrapStateController: bootstrapStateController,
            tower: tower)
        )
    }

    @MainActor
    func initializeBackgroundOperationsController() {
        // Background modes controller needs to be initialized after every other dependency is created (SDK),
        // so it needs to be called after `population`
        applicationStateController = AuthenticatedDependenciesFactory(keymaker: keymaker, tower: tower)
            .makeBackgroundModesController(container: self)
    }

    @MainActor
    func initializeDownloadAndUploadSpeedContainers() {
        // Download and upload speed measurements need to be initialized after every other dependency is created (SDK),
        // so it needs to be called after `population`
        let downloaderProcessEligibilityController = DownloaderProcessAvailabilityFactory().makeController(
            extensionTaskController: extensionTaskStateController,
            lockedStateController: lockedStateController
        )
        // Uploader eligibility basically means unifying `my files` & `photos` eligibilities.
        // Since `my files` eligibility is actually subset of `photos`, we can use photos' one.
        // If we support BG uploads for `my files` in future, this will need to be updated.
        let uploaderProcessEligibilityController = photosContainer.computationalAvailabilityController

        childContainers += [
            DownloadSpeedContainer(
                sdkFileDownloader: tower.sdkObjects.fileDownloader,
                sdkPhotoDownloader: tower.sdkObjects.photoDownloader,
                processEligibilityController: downloaderProcessEligibilityController
            ),
            UploadSpeedContainer(
                sdkUploader: tower.sdkObjects.fileUploader,
                sdkPhotoUploader: tower.sdkObjects.photoUploader,
                processEligibilityController: uploaderProcessEligibilityController
            )
        ]
    }

    func makePopulateViewController(lockedStateController: LockedStateControllerProtocol) -> UIViewController {
        // UserID can set to nil when app lock is enabled, set it back after unlocking 
        tower.localSettings.userId = tower.sessionVault.clientCredential()?.userID
        let viewController = PopulateViewController()
        let coordinator = makePopulateCoordinator(viewController)
        var viewModel = makePopulateViewModel(lockedStateController: lockedStateController, coordinator: coordinator)
        #if DEBUG
        viewModel = UITestsPopulatedViewModelDecorator(viewModel: viewModel, localSettings: localSettings)
        #endif

        viewController.viewModel = viewModel

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.isHidden = true
        navigationController.interactivePopGestureRecognizer?.isEnabled = false
        if #available(iOS 26.0, *) {
            navigationController.interactiveContentPopGestureRecognizer?.isEnabled = false
        }

        return navigationController
    }

    /// During the migration to volume DB, this method should be used wrap the feature flag controlled view model, after the migration, this should should be included as a dependency to make things clearer,
    ///  right now it's not included in order not to modify directly the legacy class.
    func makePopulateViewModel(lockedStateController: LockedStateControllerProtocol, coordinator: PopulateCoordinatorProtocol) -> PopulateViewModelProtocol {
        return FeatureFlagsAwarePopulateViewModelDecorator(
            connectionResource: tower.connectionStateResource,
            localSettings: localSettings,
            viewModel: makeAppBootstrappingPopulateViewModel(coordinator: coordinator),
            featureFlagProvider: tower.featureFlags,
            entitlementsManager: tower.entitlementsManager
        )
    }

    func makeAppBootstrappingPopulateViewModel(coordinator: PopulateCoordinatorProtocol) -> PopulateViewModelProtocol {
        let bootstrapper = makeAppBootstrapper()
        let onboardingObserver = makeOnboardingObserver()
        return BootstrappingPopulateViewModel(bootstrapper: bootstrapper, coordinator: coordinator, onboardingObserver: onboardingObserver, populatedStateController: populatedStateController)
    }

    func makeAppBootstrapper() -> AppBootstrapper {
        let addressStarter = AddressBootstrapStarter(
            localAddressProvider: self.tower.sessionVault,
            remoteAddressProvider: self.tower.addressManager,
            connectionStateResource: tower.connectionStateResource
        )
        let remoteRootShareStarter = RemoteSharesBootstrapStarter(
            listShares: { [tower] in try await tower.client.listShares(showAll: .disabled) },
            bootstrapRoot: tower.client.bootstrapRoot,
            featureFlagsController: featureFlagsController,
            storage: tower.storage,
            connectionStateResource: tower.connectionStateResource,
            volumeLockController: volumeLockController
        )
        let volumeCreator = VolumeCreator(sessionVault: tower.sessionVault, storage: tower.storage, client: tower.client)
        let creatingRootShareStarter = CreatingMainShareStarter(volumeCreator: volumeCreator, remoteRootsBootstrapper: remoteRootShareStarter)
        let localShareBootstrapStarter = LocalRootSharesBootstrapStarter(
            storage: tower.storage,
            connectionStateResource: tower.connectionStateResource
        )
        let rootShareStarter = RootSharesBootstrapStarter(
            localStore: localShareBootstrapStarter,
            remote: remoteRootShareStarter,
            creating: creatingRootShareStarter,
            connectionStateResource: tower.connectionStateResource
        )
        let eventsStarter = EventsBootstrapStarter(eventsStarter: tower, mainVolumeIdDataSource: MainVolumeIdDataSource(storage: tower.storage, context: tower.storage.backgroundContext), eventsStorageManager: tower.eventStorageManager, eventsManagedObjectContext: tower.eventStorageManager.makeNewBackgroundContext(), eventSerializer: ClientEventSerializer())
        let checklistBootstrapper = DriveChecklistBootstrapper(
            repository: StorageBonusPromoFactory().makeStoragePromoBonusStatusRepository(tower: tower),
            connectionStateResource: tower.connectionStateResource
        )
        let driveSettings = DriveUserSettingsInitializerInteractor(
            fetchUserSettingsResource: tower.client,
            localSettings: tower.localSettings,
            connectionStateResource: tower.connectionStateResource
        )
        let protonSettings = tower.generalSettings
        let b2bStatusStarter = B2BUserStatusStarter(
            featureFlags: tower.featureFlags,
            localSettings: tower.localSettings,
            networking: tower.networking,
            connectionStateResource: tower.connectionStateResource
        )
        let settingsStarter = AditionalSettingsStarter(driveSettingsInitializer: driveSettings, protonSettingsInitializer: protonSettings, b2bUserStatusStarter: b2bStatusStarter, checklistBootstrapper: checklistBootstrapper)
        let photosCacheBootstrapper = makePhotosBoostrapper()
        let volumeTypeBootstrapper = VolumeTypeBootstrapStarter(storage: tower.storage, managedObjectContext: tower.storage.backgroundContext)
        let tagsMigrationFinishChecker = TagsMigrationFinishChecker(
            connectionStateResource: tower.connectionStateResource,
            storageManager: tower.storage,
            client: tower.client,
            localSettings: tower.localSettings,
            featureFlags: featureFlagsController,
            clientUIDProvider: tower.sessionVault
        )
        let skippableCache = ConcretePhotosSkippableCache(storage: photosSkippableCacheStorage)
        let uploadingPhotosBootrapper = UploadingPhotosBootstrapper(
            skippableCache: skippableCache,
            storage: tower.storage,
            tower: tower
        )
        let paymentsBootstrapper = PaymentsBootstrapper(
            featureFlagsController: featureFlagsController,
            connectionStateResource: tower.connectionStateResource,
            coreAPIService: tower.networking
        )
        let fileManagerBootstrapper = FileManagerBootstrapper(localSettings: tower.localSettings)
        let duplicatePhotoListingBootstrapper = DuplicatePhotoListingBootstrapper(context: tower.storage.photosBackgroundContext)
        let sdkRelatedInfrastructureBootstrapper = SDKRelatedInfrastructureBootstrapper(container: self)

        return DriveBootstrapStarter(
            addressBootstrapper: addressStarter,
            sharesBootstrapper: rootShareStarter,
            volumesBootstrapper: volumeTypeBootstrapper,
            eventsBootstrapper: eventsStarter,
            settingsBootstrapper: settingsStarter,
            photosCacheBootstrapper: photosCacheBootstrapper,
            tagsMigrationFinishChecker: tagsMigrationFinishChecker,
            autoLocker: autoLocker,
            uploadingPhotosBootrapper: uploadingPhotosBootrapper,
            paymentsBootstrapper: paymentsBootstrapper,
            fileManagerBootstrapper: fileManagerBootstrapper,
            duplicatePhotoListingBootstrapper: duplicatePhotoListingBootstrapper,
            bootstrapStateController: bootstrapStateController,
            sdkRelatedInfrastructureBootstrapper: sdkRelatedInfrastructureBootstrapper,
            filePathMigrationBootstrapStarter: FilePathMigrationBootstrapStarter(),
            volumeLockController: volumeLockController,
            connectionStateResource: tower.connectionStateResource
        )
    }

    private func makePhotosBoostrapper() -> AppBootstrapper {
        let previousUserRepository = PreviouslyLoggedInUserRepositoryFactory().makeRepository(
            sessionVault: tower.sessionVault,
            keychain: DriveKeychain.shared
        )
        return PhotosCacheBootstrapper(previousUserRepository: previousUserRepository, photosSkippableStorage: photosSkippableCacheStorage)
    }

    func makeOnboardingObserver() -> OnboardingObserverProtocol {
        let onboardingObserver = OnboardingObserver(
            localSettings: localSettings,
            notificationServiceOwner: UIApplication.shared.delegate as? hasPushNotificationService,
            userId: tower.sessionVault.getCoreUserInfo()?.userId
        )
        return onboardingObserver
    }

    func makeSubscriptionsViewController() -> UIViewController {
        let container = makeSubscriptionsContainer()
        return container.makeRootViewController()
    }

    private func makePopulateCoordinator(_ viewController: PopulateViewController) -> PopulateCoordinatorProtocol {
        let subscriptionsContainer = makeSubscriptionsContainer()
        let upsellController = OneDollarUpsellFlowController(
            featureFlagEnabled: tower.featureFlags.isEnabled(flag: .oneDollarPlanUpsellEnabled),
            isPayedUser: tower.sessionVault.getUserInfo()?.isPaid == true,
            isOnboarded: localSettings.isOnboarded,
            isUpsellShown: localSettings.isUpsellShown
        )
        return PopulateCoordinator(
            viewController: viewController,
            populatedViewControllerFactory: makeHomeViewController,
            onboardingViewControllerFactory: { [localSettings] in
                OnboardingFlowFactory().makeIfNeeded(settings: localSettings)
            },
            upsellFactory: { [localSettings] in
                OneDollarUpsellFlowFactory().makeIfNeeded(controller: upsellController, settings: localSettings, container: subscriptionsContainer)
            },
            newFeaturePromoteFactory: { [weak self] in
                guard let self else { return nil }
                let newFeatureFactory = NewFeaturePromoteFactory()
                let newFeaturePromoteController = newFeatureFactory.makeController(
                    localSettings: self.localSettings,
                    featureFlagsController: self.featureFlagsController
                )
                guard newFeaturePromoteController.isAvailable() else {
                    return nil
                }
                return newFeatureFactory.makeViewController(controller: newFeaturePromoteController)
            }
        )
    }
    
    func makeSubscriptionsContainer() -> SubscriptionsContainer {
        let dependencies = SubscriptionsContainer.Dependencies(
            tower: tower,
            keymaker: keymaker,
            networkService: networkService,
            featureFlagsController: featureFlagsController
        )
        return SubscriptionsContainer(dependencies: dependencies)
    }
    
    @MainActor
    func makeUpsellCoordinator() -> UpsellCoordinator {
        let upsellContainer = UpsellContainer(
            dependencies: UpsellContainer.Dependencies(
                tower: tower,
                featureFlagsController: featureFlagsController,
                userInfoController: UserInfoControllerFactory().makeController(sessionVault: tower.sessionVault)
            )
        )
        return UpsellCoordinator(
            container: upsellContainer,
            subscriptionsContainer: makeSubscriptionsContainer()
        )
    }
}

protocol EventsSystemStarter {
    func startEventsSystem()
}

extension Tower: EventsSystemStarter {
    func startEventsSystem() {
        start(options: [.runEventsProcessor, .initializeAllVolumes])
    }
}

extension NotificationCenter {
    func mappedPublisher<T>(for notificationName: Notification.Name, transformer: @escaping (Any?) -> T) -> AnyPublisher<T, Never> {
        self.publisher(for: notificationName).map { transformer($0) }.eraseToAnyPublisher()
    }
}

extension NotificationCenter {
    func mappedPublisher(for notificationName: Notification.Name) -> AnyPublisher<Void, Never> {
        self.publisher(for: notificationName).map { _ in Void() }.eraseToAnyPublisher()
    }
}
