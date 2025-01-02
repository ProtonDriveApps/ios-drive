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
    let protonDocumentContainer: ProtonDocumentPreviewContainer
    let featureFlagsController: FeatureFlagsController
    let authenticator: Authenticator
    let contactsManager: ContactsManagerProtocol
    let sharedVolumesEventsContainer: SharedVolumesEventsContainer
    let populatedStateController: PopulatedStateControllerProtocol
    let contactEventBridge: ContactUpdateDelegate

    init(tower: Tower, keymaker: Keymaker, networkService: PMAPIService, localSettings: LocalSettings, windowScene: UIWindowScene, settingsSuite: SettingsStorageSuite, authenticator: Authenticator, populatedStateController: PopulatedStateControllerProtocol) {
        self.tower = tower
        self.keymaker = keymaker
        self.networkService = networkService
        self.localSettings = localSettings
        self.windowScene = windowScene
        self.authenticator = authenticator
        self.contactsManager = ContactsManager(
            service: networkService,
            log: { desc in Log.info(desc, domain: .contact) },
            error: { desc in Log.error(desc, domain: .contact) }
        )
        self.populatedStateController = populatedStateController
        contactEventBridge = ContactEventBridge(contactsManager: contactsManager)
        tower.contactAdapter.delegate = contactEventBridge

        let myFilesUploadOperationInteractor = MyFilesUploadOperationInteractor(storage: tower.storage, interactor: tower.fileUploader)
        pickersContainer = PickersContainer()

        var operationInteractors: [OperationInteractor] = [
            myFilesUploadOperationInteractor,
            pickersContainer.photoPickerInteractor
        ]

        let extensionStateController = ConcreteBackgroundTaskStateController()

        let photoSkippableCache = ConcretePhotosSkippableCache(storage: UserDefaultsPhotosSkippableStorage())
        featureFlagsController = FeatureFlagsController(buildType: Constants.buildType, featureFlagsStore: localSettings, updateRepository: tower.featureFlags)
        let notificationFlowController = NotificationsPermissionsFactory().makeFlowController()
        let dependencies = PhotosContainer.Dependencies(
            tower: tower,
            windowScene: windowScene,
            keymaker: keymaker,
            networkService: networkService,
            settingsSuite: settingsSuite,
            extensionStateController: extensionStateController,
            photoSkippableCache: photoSkippableCache,
            notificationsPermissionsFlowController: notificationFlowController,
            contacstsManager: contactsManager,
            featureFlagsController: featureFlagsController,
            populatedStateController: populatedStateController
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

        protonDocumentContainer = ProtonDocumentPreviewContainer(
            dependencies: .init(
                tower: tower,
                featureFlagsController: featureFlagsController,
                apiService: networkService,
                authenticator: authenticator
            )
        )
        sharedVolumesEventsContainer = SharedVolumesEventsContainer(tower: tower, featureFlagsController: featureFlagsController)
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
        let remoteRootShareStarter = CachingRootSharesBootstrapStarter(listShares: tower.client.listShares, bootstrapRoot: tower.client.bootstrapRoot, storage: tower.storage)
        let volumeCreator = VolumeCreator(sessionVault: tower.sessionVault, storage: tower.storage, client: tower.client)
        let creatingRootShareStarter = CreatingMainShareStarter(volumeCreator: volumeCreator, remoteRootsBootstrapper: remoteRootShareStarter)
        let rootShareStarter = RootSharesBootstrapStarter(localStore: localRootShareStarter, remote: remoteRootShareStarter, creating: creatingRootShareStarter)
        let eventsStarter = EventsBootstrapStarter(eventsStarter: tower, mainVolumeIdDataSource: MainVolumeIdDataSource(storage: tower.storage, context: tower.storage.backgroundContext), eventsStorageManager: tower.eventStorageManager, eventsManagedObjectContext: tower.eventStorageManager.makeNewBackgroundContext(), eventSerializer: ClientEventSerializer())
        let settingsUpdater = TabbarSettingUpdater(client: tower.client, featureFlags: tower.featureFlags, localSettings: tower.localSettings, networking: tower.networking, storageManager: tower.storage)
        let settingsStarter = AditionalSettingsStarter(generalSettings: tower.generalSettings, storage: tower.storage, settingsUpdater: settingsUpdater)
        return DriveBootstrapStarter(addressBootstrapper: addressStarter, sharesBootstrapper: rootShareStarter, eventsBootstrapper: eventsStarter, settingsBootstrapper: settingsStarter)
    }

    func makeOnboardingObserver() -> OnboardingObserverProtocol {
        let onboardingObserver = OnboardingObserver(
            localSettings: localSettings,
            notificationServiceOwner: UIApplication.shared.delegate as? hasPushNotificationService,
            userId: tower.sessionVault.getCoreUserInfo()?.userId
        )
        return onboardingObserver
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
        start(options: [.runEventsProcessor, .initializeSharedVolumes])
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
