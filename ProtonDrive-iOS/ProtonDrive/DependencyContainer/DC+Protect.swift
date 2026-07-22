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
import ProtonCoreKeymaker
import ProtonCoreServices
import ProtonCoreHumanVerification
import PDSDKCore
import PDSDKCoreiOS

extension DriveDependencyContainer {
    @MainActor
    func makeProtectViewController() async -> UIViewController {
        let factory = ProtectViewControllerFactory(
            lockedStateController: lockedStateController,
            keymaker: keymaker,
            networkService: networkService
        ) { [weak self] controller in
            guard let self else { return UIViewController() }
            let authenticatedContainer = await self.initializeAuthenticatedDependencies(
                lockedStateController: controller
            )
            return authenticatedContainer.makePopulateViewController(lockedStateController: controller)
        }
        return factory.makeProtectViewController()
    }

    @MainActor
    private func initializeAuthenticatedDependencies(
        lockedStateController: LockedStateControllerProtocol
    ) async -> AuthenticatedDependencyContainer {
        let populatedController = PopulatedStateController()
        let tower = await initializeTowerInBackgroundQueue(populatedController: populatedController)
        signOutManager.appIsUnlocked(tower: tower)
        let featureFlagsController = FeatureFlagsController(
            buildType: Constants.buildType,
            featureFlagsStore: localSettings,
            updateRepository: tower.featureFlags
        )
        let photoUploadedNotifier = ConcretePhotoUploadedNotifier(moc: tower.storage.photosSecondaryBackgroundContext)
        let failedPhotosResource = InMemoryDeletedPhotosIdentifierStoreResource()
        let photosSkippableCacheStorage = UserDefaultsPhotosSkippableStorage()
        await initializeSDK(
            tower: tower,
            featureFlagsController: featureFlagsController,
            photoUploadedNotifier: photoUploadedNotifier,
            failedPhotosResource: failedPhotosResource,
            photosSkippableCacheStorage: photosSkippableCacheStorage
        )
        let authenticatedContainer = AuthenticatedDependencyContainer(
            tower: tower,
            keymaker: keymaker,
            networkService: networkService,
            localSettings: localSettings,
            settingsSuite: appGroup,
            authenticator: authenticator,
            populatedStateController: populatedController,
            autoLocker: autoLocker,
            featureFlagsController: featureFlagsController,
            photoUploadedNotifier: photoUploadedNotifier,
            failedPhotosResource: failedPhotosResource,
            photosSkippableCacheStorage: photosSkippableCacheStorage,
            lockedStateController: lockedStateController
        )

        self.authenticatedContainer = authenticatedContainer
        return authenticatedContainer
    }

    func initializeSDK(
        tower: Tower,
        featureFlagsController: FeatureFlagsControllerProtocol,
        photoUploadedNotifier: PhotoUploadedNotifier,
        failedPhotosResource: DeletedPhotosIdentifierStoreResource,
        photosSkippableCacheStorage: PhotosSkippableStorage
    ) async {
        let skippableCache = ConcretePhotosSkippableCache(storage: photosSkippableCacheStorage)
        let sdkBootstrapper = SDKBootstrapStarter(
            dependencies: .init(
                tower: tower,
                featureFlagsController: featureFlagsController,
                connectionStateResource: tower.connectionStateResource,
                keymaker: keymaker,
                photoUploadedNotifier: photoUploadedNotifier,
                skippableCache: skippableCache,
                failedPhotosResource: failedPhotosResource
            )
        )
        try? await sdkBootstrapper.bootstrap()
    }

    func initializeTowerInBackgroundQueue(populatedController: PopulatedStateControllerProtocol) async -> Tower {
        Log.info("Initializing Tower", domain: .application)
        let tower = Tower(
            storage: storageManager,
            eventStorage: EventStorageManager(suiteUrl: appGroup.directoryUrl),
            appGroup: appGroup,
            mainKeyProvider: keymaker,
            sessionVault: sessionVault,
            sessionCommunicator: sessionCommunicator,
            authenticator: authenticator,
            clientConfig: Constants.clientApiConfig,
            network: networkService,
            eventObservers: [],
            eventProcessingMode: .full,
            eventLoopInterval: 90,
            localSettings: localSettings,
            populatedStateController: populatedController,
            connectionStateResource: connectionStateResource
        )
        tower.subscribe(isLockedPublisher: lockedStateController.isLocked)
        return tower
    }
}
