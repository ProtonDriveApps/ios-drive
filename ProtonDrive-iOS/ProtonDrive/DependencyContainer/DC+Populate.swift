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

final class AuthenticatedDependencyContainer {
    let tower: Tower
    let keymaker: Keymaker
    let networkService: PMAPIService
    let localSettings: LocalSettings
    let applicationStateController: ApplicationStateOperationsController
    let windowScene: UIWindowScene
    let childContainers: [Any]
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
    private let photosSkippableCacheStorage: PhotosSkippableStorage
    let scrollToTopSubject = PassthroughSubject<TabBarItem, Never>()
    private weak var autoLocker: Autolocker?

    init(tower: Tower, keymaker: Keymaker, networkService: PMAPIService, localSettings: LocalSettings, windowScene: UIWindowScene, settingsSuite: SettingsStorageSuite, authenticator: Authenticator, populatedStateController: PopulatedStateControllerProtocol, autoLocker: Autolocker?) {
        self.tower = tower
        self.keymaker = keymaker
        self.networkService = networkService
        self.localSettings = localSettings
        self.windowScene = windowScene
        self.authenticator = authenticator
        self.contactsManager = ContactsManager(
            service: networkService,
            log: { desc in Log.info(desc, domain: .contact) },
            error: { desc in Log.error(desc, error: nil, domain: .contact) }
        )
        self.populatedStateController = populatedStateController
        self.autoLocker = autoLocker
        contactEventBridge = ContactEventBridge(contactsManager: contactsManager)
        tower.contactAdapter.delegate = contactEventBridge
        let converter = ExternalInvitationConverter(
            client: tower.client,
            contactsManager: contactsManager,
            inviteHandler: InternalUserInviteInteractor(client: tower.client, encryptionResource: Encryptor()),
            signersFactory: tower.sessionVault
        )
        tower.set(externalInvitationConverter: converter)

        let myFilesUploadOperationInteractor = MyFilesUploadOperationInteractor(storage: tower.storage, interactor: tower.fileUploader)
        pickersContainer = PickersContainer()

        var operationInteractors: [OperationInteractor] = [
            myFilesUploadOperationInteractor,
            pickersContainer.photoPickerInteractor
        ]

        let extensionStateController = ConcreteBackgroundTaskStateController()

        photosSkippableCacheStorage = UserDefaultsPhotosSkippableStorage()
        featureFlagsController = FeatureFlagsController(buildType: Constants.buildType, featureFlagsStore: localSettings, updateRepository: tower.featureFlags)
        let notificationFlowController = NotificationsPermissionsFactory().makeFlowController()
        ratingBoosterFlowController = RatingBoosterFlowController(
            coordinator: RatingBoosterCoordinator(windowScene: windowScene),
            featureFlagsController: featureFlagsController,
            localSettings: localSettings,
            repository: DisableLegacyRatingRepository(networkService: tower.networking)
        )
        let dependencies = PhotosContainer.Dependencies(
            tower: tower,
            windowScene: windowScene,
            keymaker: keymaker,
            networkService: networkService,
            settingsSuite: settingsSuite,
            extensionStateController: extensionStateController,
            photoSkippableCache: ConcretePhotosSkippableCache(storage: photosSkippableCacheStorage),
            notificationsPermissionsFlowController: notificationFlowController,
            contacstsManager: contactsManager,
            featureFlagsController: featureFlagsController,
            populatedStateController: populatedStateController,
            scrollToTopPublisher: scrollToTopSubject.eraseToAnyPublisher()
        )
        photosContainer = PhotosContainer(dependencies: dependencies)

        let photosUploadOperationInteractor = PhotosUploadOperationInteractor(uploadingFiles: photosContainer.uploadingPhotosRepository.getPhotos, interactor: photosContainer.uploader)
        operationInteractors.append(photosUploadOperationInteractor)

        let operationsInteractor = AggregatedOperationInteractor(interactors: operationInteractors)
        #if SUPPORTS_BACKGROUND_UPLOADS
        let processingController = ProcessingBackgroundOperationController(
            operationInteractor: operationsInteractor,
            taskResource: ProcessingExtensionBackgroundTaskResourceImpl()
        )
        let backgroundOperationController = ExtensionBackgroundOperationController(
            processingController: processingController,
            extensionStateController: extensionStateController,
            operationInteractor: uploadOperationInteractor,
            taskResource: ExtensionBackgroundTaskResourceImpl()
        )
        #else
        let backgroundOperationController = ExtensionBackgroundOperationController(
            extensionStateController: extensionStateController,
            operationInteractor: operationsInteractor,
            taskResource: ExtensionBackgroundTaskResourceImpl()
        )
        #endif

        applicationStateController = ApplicationStateOperationsController(
            applicationStateResource: iOSApplicationRunningStateResource(),
            backgroundOperationController: backgroundOperationController
        )

        // Child containers
        childContainers = [
            LocalNotificationsContainer(tower: tower),
            MyFilesNotificationsPermissionsContainer(tower: tower, windowScene: windowScene, flowController: notificationFlowController),
            ForegroundTransitionContainer(tower: tower, pickerResource: pickersContainer.photoPickerResource, populatedStateController: populatedStateController),
            QuotaUpdatesContainer(tower: tower, photoUploader: photosContainer.uploader),
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
    }

    func makePopulateViewController(lockedStateController: LockedStateControllerProtocol) -> UIViewController {
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

        return navigationController
    }

    /// During the migration to volume DB, this method should be used wrap the feature flag controlled view model, after the migration, this should should be included as a dependency to make things clearer,
    ///  right now it's not included in order not to modify directly the legacy class.
    func makePopulateViewModel(lockedStateController: LockedStateControllerProtocol, coordinator: PopulateCoordinatorProtocol) -> PopulateViewModelProtocol {
        return FeatureFlagsAwarePopulateViewModelDecorator(
            localSettings: localSettings,
            viewModel: makeAppBootstrappingPopulateViewModel(coordinator: coordinator),
            featureFlagsRepository: tower.featureFlags,
            entitlementsManager: tower.entitlementsManager
        )
    }

    func makeAppBootstrappingPopulateViewModel(coordinator: PopulateCoordinatorProtocol) -> PopulateViewModelProtocol {
        let bootstrapper = makeAppBootstrapper()
        let onboardingObserver = makeOnboardingObserver()
        return BootstrappinggPopulateViewModel(bootstrapper: bootstrapper, coordinator: coordinator, onboardingObserver: onboardingObserver, populatedStateController: populatedStateController)
    }

    func makeAppBootstrapper() -> AppBootstrapper {
        let addressStarter = AddressBootstrapStarter(localAddressProvider: self.tower.sessionVault, remoteAddressProvider: self.tower.addressManager)
        let localRootShareStarter = LocalRootSharesBootstrapStarter(storage: tower.storage)
        let remoteRootShareStarter = RemoteSharesBootstrapStarter(listShares: tower.client.listShares, bootstrapRoot: tower.client.bootstrapRoot, featureFlagsController: featureFlagsController, storage: tower.storage)
        let volumeCreator = VolumeCreator(sessionVault: tower.sessionVault, storage: tower.storage, client: tower.client)
        let creatingRootShareStarter = CreatingMainShareStarter(volumeCreator: volumeCreator, remoteRootsBootstrapper: remoteRootShareStarter)
        let rootShareStarter = RootSharesBootstrapStarter(localStore: localRootShareStarter, remote: remoteRootShareStarter, creating: creatingRootShareStarter)
        let eventsStarter = EventsBootstrapStarter(eventsStarter: tower, mainVolumeIdDataSource: MainVolumeIdDataSource(storage: tower.storage, context: tower.storage.backgroundContext), eventsStorageManager: tower.eventStorageManager, eventsManagedObjectContext: tower.eventStorageManager.makeNewBackgroundContext(), eventSerializer: ClientEventSerializer())
        let settingsUpdater = TabbarSettingUpdater(client: tower.client, featureFlags: tower.featureFlags, localSettings: tower.localSettings, networking: tower.networking, storageManager: tower.storage)
        let checklistBootstrapper = DriveChecklistBootstrapper(repository: StorageBonusPromoFactory().makeStoragePromoBonusStatusRepository(tower: tower))
        let driveSettings = DriveUserSettingsInitializerInteractor(fetchUserSettingsResource: tower.client, localSettings: tower.localSettings)
        let protonSettings = tower.generalSettings
        let b2bStatusStarter = B2BUserStatusStarter(featureFlags: tower.featureFlags, localSettings: tower.localSettings, networking: tower.networking)
        let settingsStarter = AditionalSettingsStarter(driveSettingsInitializer: driveSettings, protonSettingsInitializer: protonSettings, b2bUserStatusStarter: b2bStatusStarter, checklistBootstrapper: checklistBootstrapper)
        let photosCacheBootstrapper = makePhotosBoostrapper()
        let volumeTypeBootstrapper = VolumeTypeBootstrapStarter(storage: tower.storage, managedObjectContext: tower.storage.backgroundContext)
        let tagsMigrationFinishChecker = TagsMigrationFinishChecker(
            storageManager: tower.storage,
            client: tower.client,
            localSettings: tower.localSettings,
            featureFlags: featureFlagsController,
            clientUIDProvider: tower.sessionVault
        )
        return DriveBootstrapStarter(addressBootstrapper: addressStarter, sharesBootstrapper: rootShareStarter, volumesBootstrapper: volumeTypeBootstrapper, eventsBootstrapper: eventsStarter, settingsBootstrapper: settingsStarter, photosCacheBootstrapper: photosCacheBootstrapper, tagsMigrationFinishChecker: tagsMigrationFinishChecker, autoLocker: autoLocker)
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
        let dependencies = SubscriptionsContainer.Dependencies(
            tower: tower,
            keymaker: keymaker,
            networkService: networkService
        )
        let container = SubscriptionsContainer(dependencies: dependencies)
        return container.makeRootViewController()
    }

    private func makePopulateCoordinator(_ viewController: PopulateViewController) -> PopulateCoordinatorProtocol {
        let subscriptionsContainer = SubscriptionsContainer(
            dependencies: SubscriptionsContainer.Dependencies(tower: tower, keymaker: keymaker, networkService: networkService)
        )
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
}

protocol EventsSystemStarter {
    func startEventsSystem()
}

extension Tower: EventsSystemStarter {
    func startEventsSystem() {
        start(options: [.runEventsProcessor, .initializeAllVolumes])
    }
}

protocol SignOutManager {
    func signOut() async
}

extension Tower: SignOutManager {
    func signOut() async {
        await signOut(cacheCleanupStrategy: .cleanEverything)

        // notify cross-process observers
        DarwinNotificationCenter.shared.postNotification(.DidLogout)
    }
}

protocol LockManager {
    func onLock()
}

extension Tower: LockManager {
    func onLock() {
        stop()
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
