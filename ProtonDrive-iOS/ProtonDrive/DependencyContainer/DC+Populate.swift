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
import ProtonCoreFeatureFlags
import ProtonCoreHumanVerification
import ProtonCoreKeymaker
import ProtonCoreServices
import UserNotifications
import SwiftUI
import PDUIComponents

final class AuthenticatedDependencyContainer {
    let tower: Tower
    let keymaker: Keymaker
    let networkService: PMAPIService
    let localSettings: LocalSettings
    let applicationStateController: ApplicationStateOperationsController
    let windowScene: UIWindowScene
    let factory = TabBarViewControllerFactory()
    let childContainers: [Any]
    var humanCheckHelper: HumanCheckHelper?
    let pickersContainer: PickersContainer
    #if HAS_PHOTOS
    let photosContainer: PhotosContainer
    #endif

    init(tower: Tower, keymaker: Keymaker, networkService: PMAPIService, localSettings: LocalSettings, windowScene: UIWindowScene, settingsSuite: SettingsStorageSuite) {
        self.tower = tower
        self.keymaker = keymaker
        self.networkService = networkService
        self.localSettings = localSettings
        self.windowScene = windowScene

        let myFilesUploadOperationInteractor = MyFilesUploadOperationInteractor(storage: tower.storage, interactor: tower.fileUploader)
        pickersContainer = PickersContainer()

        var operationInteractors: [OperationInteractor] = [
            myFilesUploadOperationInteractor,
            pickersContainer.photoPickerInteractor
        ]

        let extensionStateController = ConcreteBackgroundTaskStateController()
        var photosInteractor: CommandInteractor?
        
        #if OPTIMIZED_PHOTO_UPLOADS
        let photoSkippableCache = ConcretePhotosSkippableCache(storage: UserDefaultsPhotosSkippableStorage())
        #else
        let photoSkippableCache = BlankPhotosSkippableCache()
        #endif

        #if HAS_PHOTOS
        let dependencies = PhotosContainer.Dependencies(tower: tower, windowScene: windowScene, keymaker: keymaker, networkService: networkService, settingsSuite: settingsSuite, extensionStateController: extensionStateController, photoSkippableCache: photoSkippableCache)
        photosContainer = PhotosContainer(dependencies: dependencies)
        photosInteractor = PhotosInterruptedUploadsInteractor(uploadingFiles: photosContainer.uploadingPhotosRepository.getPhotos, uploader: photosContainer.uploader)

        let photosUploadOperationInteractor = PhotosUploadOperationInteractor(uploadingFiles: photosContainer.uploadingPhotosRepository.getPhotos, interactor: photosContainer.uploader)
        operationInteractors.append(photosUploadOperationInteractor)
        #endif

        let applicationRunningResource = ApplicationRunningStateResourceImpl()
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
            applicationStateResource: applicationRunningResource,
            backgroundOperationController: backgroundOperationController
        )

        #if HAS_PHOTOS
        let quotaUpdatesContainer = QuotaUpdatesContainer(tower: tower, photoUploader: photosContainer.uploader)
        #else
        let quotaUpdatesContainer = QuotaUpdatesContainer(tower: tower)
        #endif
        
        // Child containers
        childContainers = [
            LocalNotificationsContainer(tower: tower),
            MyFilesNotificationsPermissionsContainer(tower: tower, windowScene: windowScene),
            ForegroundTransitionContainer(tower: tower, pickerResource: pickersContainer.photoPickerResource, photosInteractor: photosInteractor),
            quotaUpdatesContainer,
        ]
    }

    func makePopulateViewController(lockedStateController: LockedStateControllerProtocol) -> UIViewController {
        let viewController = PopulateViewController()
        let coordinator = makePopulateCoordinator(viewController)
        let viewModel = makePopulateViewModel(lockedStateController: lockedStateController, coordinator: coordinator)
        viewController.viewModel = viewModel

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.isHidden = true
        navigationController.interactivePopGestureRecognizer?.isEnabled = false

        return navigationController
    }

    private func makePopulateViewModel(lockedStateController: LockedStateControllerProtocol, coordinator: PopulateCoordinatorProtocol) -> PopulateViewModel {
        let populatedStateController = PopulatedStateController(populator: tower)
        let onboardingObserver = OnboardingObserver(
            localSettings: localSettings,
            notificationServiceOwner: UIApplication.shared.delegate as? hasPushNotificationService,
            userId: tower.sessionVault.getCoreUserInfo()?.userId
        )
        return PopulateViewModel(lockedStateController: lockedStateController, populatedStateController: populatedStateController, populator: tower, eventsStarter: tower, onboardingObserver: onboardingObserver, coordinator: coordinator)
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
            }
        )
    }
    
}

protocol DrivePopulator {
    var state: PopulatedState { get }
    func populate(onCompletion: @escaping (Result<Void, Error>) -> Void)
}

extension Tower: DrivePopulator {
    var state: PopulatedState {
        if let root = rootFolderIdentifier() {
            return .populated(with: root)
        } else {
            return .unpopulated
        }
    }

    func populate(onCompletion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let config: FirstBootConfiguration = .init(isPhotoEnabled: true, isTabSettingsRequested: true)
                try await onFirstBoot(config: config)
                await MainActor.run {
                    onCompletion(.success(Void()))
                }
            } catch {
                await MainActor.run {
                    onCompletion(.failure(error))
                }
            }
        }
    }
}

protocol EventsSystemStarter {
    func startEventsSystem()
}

extension Tower: EventsSystemStarter {
    func startEventsSystem() {
        start(runEventsProcessor: true)
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
