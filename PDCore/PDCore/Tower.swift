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
import CoreData
import PDClient
import PMEventsManager
import ProtonCoreAuthentication
import ProtonCoreServices
import ProtonCoreKeymaker
import ProtonCoreNetworking
import ProtonCoreDataModel
import ProtonCoreFeatureFlags

typealias ResponseError = ProtonCoreNetworking.ResponseError

public class Tower: NSObject {
    typealias CoreEventLoopManager = EventPeriodicScheduler<GeneralEventsLoopWithProcessor, DriveEventsLoop>

    public let fileUploader: FileUploader
    public let fileImporter: FileImporter
    public let revisionImporter: RevisionImporter
    public let uploadVerifierFactory: UploadVerifierFactory
    public let downloader: Downloader!
    public let uiSlot: UISlot!
    public let cloudSlot: CloudSlot!
    public let fileSystemSlot: FileSystemSlot!
    public let sessionVault: SessionVault
    public let sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions
    public let localSettings: LocalSettings
    public let paymentsStorage: PaymentsSecureStorage
    public let offlineSaver: OfflineSaver?

    public var photoUploader: FileUploader?

    public let api: PDClient.APIService
    public let storage: StorageManager
    public let syncStorage: SyncStorageManager?
    public let client: PDClient.Client
    public let addressManager: AddressManager
    internal let sharingManager: SharingManager
    internal let thumbnailLoader: CancellableThumbnailLoader
    public let generalSettings: GeneralSettings
    public let featureFlags: FeatureFlagsRepository
    
    // internal for Tower+Events.swift
    internal let eventsConveyor: EventsConveyor
    internal let coreEventManager: CoreEventLoopManager
    internal let eventObservers: [EventsListener]
    internal let eventProcessingMode: DriveEventsLoopMode
    #if HAS_QA_FEATURES
    public static let shouldFetchEventsStorageKey = "shouldFetchEvents"
    @SettingsStorage("shouldFetchEvents") public var shouldFetchEvents: Bool? {
        didSet {
            guard oldValue != shouldFetchEvents, let shouldFetchEvents else { return }
            if shouldFetchEvents {
                runEventsSystem()
            } else {
                pauseEventsSystem()
            }
        }
    }
    #endif
    
    private let networking: PMAPIService
    private let authenticator: Authenticator

    // Clean up
    public var cleanUpController: CleanUpEventController {
        cleanUpStartController
    }
    private let cleanUpStartController: CleanUpStartController

    public init(storage: StorageManager,
                syncStorage: SyncStorageManager? = nil,
                eventStorage: EventStorageManager,
                appGroup: SettingsStorageSuite,
                mainKeyProvider: Keymaker,
                sessionVault: SessionVault,
                sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions,
                authenticator: Authenticator,
                clientConfig: PDClient.APIService.Configuration,
                network: PMAPIService,
                eventObservers: [EventsListener],
                eventProcessingMode: DriveEventsLoopMode,
                networkSpy: DriveAPIService? = nil,
                uploadVerifierFactory: UploadVerifierFactory,
                localSettings: LocalSettings
    ) {
        self.storage = storage
        self.syncStorage = syncStorage
        self.uiSlot = UISlot(storage: storage)
        
        self.localSettings = localSettings
        self.generalSettings = GeneralSettings(mainKeyProvider: mainKeyProvider, network: network, localSettings: localSettings)
        self.sessionVault = sessionVault
        self.sessionCommunicator = sessionCommunicator
        self.api = APIServiceFactory().makeService(configuration: clientConfig)
        
        self.networking = network
        self.addressManager = AddressManager(authenticator: authenticator, sessionVault: sessionVault)
        self.authenticator = authenticator
        
        let client = Client(credentialProvider: self.sessionVault, service: api, networking: networkSpy ?? network)
        client.errorMonitor = ErrorMonitor(Log.deserializationErrors)
        self.client = client

        let cloudSlot = CloudSlot(client: client, storage: storage, sessionVault: sessionVault)
        self.cloudSlot = cloudSlot

        let endpointFactory = DriveEndpointFactory(service: api, credentialProvider: sessionVault)
        let downloader = Downloader(cloudSlot: cloudSlot, endpointFactory: endpointFactory)
        self.downloader = downloader
        
        self.sharingManager = SharingManager(cloudSlot: cloudSlot, sessionVault: sessionVault)
        
        self.featureFlags = FeatureFlagsRepositoryFactory().makeRepository(
           configuration: clientConfig,
           networking: network,
           store: localSettings
       )

        // Thumbnails
        self.thumbnailLoader = ThumbnailLoaderFactory().makeFileThumbnailLoader(storage: storage, cloudSlot: cloudSlot, client: client)

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        self.fileSystemSlot = FileSystemSlot(baseURL: documents, storage: self.storage, syncStorage: self.syncStorage)

        // Events
        let paymentsStorage = PaymentsSecureStorage(mainKeyProvider: mainKeyProvider)
        self.paymentsStorage = paymentsStorage
        
        self.eventsConveyor = EventsConveyor(storage: eventStorage, suite: appGroup)
        self.eventObservers = eventObservers
        self.eventProcessingMode = eventProcessingMode
        self.coreEventManager = Self.makeCoreEventsSystem(appGroup: appGroup, sessionVault: sessionVault, generalSettings: generalSettings, paymentsSecureStorage: paymentsStorage, network: network)

        self.uploadVerifierFactory = uploadVerifierFactory

        // Files
        self.fileImporter = CoreDataFileImporter(moc: cloudSlot.moc, signersKitFactory: sessionVault, uploadClientUIDProvider: sessionVault)
        self.revisionImporter = CoreDataRevisionImporter(signersKitFactory: sessionVault, uploadClientUIDProvider: sessionVault)

        #if os(macOS)
        self.fileUploader = FileUploader(
            fileUploadFactory: DiscreteFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, verifierFactory: uploadVerifierFactory, apiService: api, client: client).make(),
            filecleaner: cloudSlot,
            moc: storage.backgroundContext
        )
        self.offlineSaver = nil
        #else
        if Constants.runningInExtension {
            self.fileUploader = FileUploader(
                fileUploadFactory: StreamFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, verifierFactory: uploadVerifierFactory, apiService: api, client: client).make(),
                filecleaner: cloudSlot,
                moc: storage.backgroundContext
            )
            self.offlineSaver = nil
        } else {
            self.fileUploader = MyFilesFileUploader(
                fileUploadFactory: iOSFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, verifierFactory: uploadVerifierFactory, apiService: api, client: client).make(),
                filecleaner: cloudSlot,
                moc: storage.backgroundContext
            )
            self.offlineSaver = OfflineSaver(clientConfig: clientConfig, storage: storage, downloader: downloader)
        }
        #endif

        cleanUpStartController = CleanUpController()

        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadCache), name: .nukeCache, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadCacheExcludingEvents), name: .nukeCacheExcludingEvents, object: nil)
    }

    public func bootstrap() async throws {
        try await withCheckedThrowingContinuation { continuation in
            onFirstBoot(continuation.resume(with:))
        }
    }
    
    public func bootstrapIfNeeded() async throws {
        guard rootFolderAvailable() == false else { return }
        return try await bootstrap()
    }
    
    public func cleanUpEventsAndMetadata(cleanupStrategy: CacheCleanupStrategy) async {
        if cleanupStrategy.shouldCleanEvents {
            discardEventsPolling()
        }
        if cleanupStrategy.shouldCleanMetadata {
            await storage.clearUp()
        }
    }

    @MainActor
    public func signOut(cacheCleanupStrategy: CacheCleanupStrategy) async {
        if let userId = sessionVault.userInfo?.ID {
            ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.resetFlags(for: userId)
            ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.clearUserId()
        }
        await destroyCache(strategy: cacheCleanupStrategy)
        featureFlags.stop() // stop when logged out
        await removeSessionInBE() // Before sessionVault clean to have the credential
        sessionVault.signOut()
        sessionCommunicator.clearStateOnSignOut()
    }

    @MainActor
    private func destroyCache(strategy cacheCleanupStrategy: CacheCleanupStrategy) async {
        photoUploader?.didSignOut = true
        photoUploader?.cancelAllOperations()
        fileUploader.didSignOut = true
        fileUploader.cancelAllOperations()

        if cacheCleanupStrategy.shouldCleanEvents {
            discardEventsPolling()
        }

        /// The clean up follows a certain order. Right now any subscriber of `cleanUpController` will execute their work before any other cleanup (storage, vault, etc).
        /// There might be more coordination needed in the future, think about how to indicate which domain of resources should react to a notification.
        /// Tips: (parametrizing `start` function / multiple functions - one per domain / multiple cleanup controllers - one per domain)...
        cleanUpStartController.start()

        downloader.cancelAll()
        thumbnailLoader.cancelAll()
        offlineSaver?.cleanUp()
        fileSystemSlot.clear()
        localSettings.cleanUp()
        generalSettings.cleanUp()

        if cacheCleanupStrategy.shouldCleanMetadata {
            await storage.clearUp()
        }
        await syncStorage?.clearUp()

        PDFileManager.destroyPermanents()
        PDFileManager.destroyCaches()
        PDFileManager.clearLogsDirectory()

        UserDefaults.standard.dictionaryRepresentation().forEach { key, _ in
            UserDefaults.standard.removeObject(forKey: key)
        }
        URLCache.shared.removeAllCachedResponses()

        try? PDFileManager.bootstrapLogDirectory()
    }

    private func removeSessionInBE() async {
        Log.info("Attempting logout", domain: .networking)
        guard let coreCredential = sessionVault.sessionCredential else { return }
        let credential = Credential(coreCredential)

        await withCheckedContinuation { continuation in
            authenticator.closeSession(credential) { result in
                switch result {
                case .success:
                    Log.info("Logout successful", domain: .networking)
                    continuation.resume(returning: Void())
                case .failure(let error):
                    Log.error(error, domain: .networking)
                    continuation.resume(returning: Void())
                }
            }
        }
    }

    /// Clears local cache without clearing the user session
    @objc private func reloadCache() {
        Task {
            Log.info("Tower - nukeCache", domain: .application)
            await destroyCache(strategy: .cleanEverything)
            NotificationCenter.default.post(name: .restartApplication, object: nil)
        }
    }

    @objc private func reloadCacheExcludingEvents() {
        Task {
            Log.info("Tower - nukeCacheExcludingEvent", domain: .application)
            await destroyCache(strategy: .cleanMetadataDBButDoNotCleanEvents)
            NotificationCenter.default.post(name: .restartApplication, object: nil)
        }
    }

    // things we need to do once
    public func onFirstBoot(isPhotosEnabled: Bool = false, _ completion: @escaping (Result<Void, Error>) -> Void) {
        if let addresses = sessionVault.addresses, sessionVault.userInfo != nil {
            firstBoot(isPhotosEnabled: isPhotosEnabled, with: addresses, completion)
        } else {
            self.addressManager.fetchAddresses { [weak self] in
                guard case Result.success(let addresses) = $0 else {
                    return completion( $0.flatMap { _ in .success(Void()) })
                }
                self?.firstBoot(isPhotosEnabled: isPhotosEnabled, with: addresses, completion)
            }
        }
    }

    private func firstBoot(isPhotosEnabled: Bool, with addresses: [Address], _ completion: @escaping (Result<Void, Error>) -> Void) {
        let activeAddresses = addresses.filter({ !$0.keys.isEmpty })
        guard let primaryAddress = activeAddresses.first else {
            return completion(.failure(AddressManager.Errors.noPrimaryAddress))
        }

        guard let signersKit = try? SignersKit(address: primaryAddress, sessionVault: self.sessionVault) else {
            return completion(.failure(SignersKit.Errors.noAddressWithRequestedSignature))
        }
        
        featureFlags.start { _ in } // initial fetching during login, error is ignored, we will use cache or defaults
        self.generalSettings.fetchUserSettings() // opportunistic, no need to abort the boot if this call fails
        
        let withMainShare: (Result<Share, Error>) -> Void = { sharesResult in
            switch sharesResult {
            case let .failure(error):
                completion(.failure(error))
            case .success:
                completion(.success(Void()))
            }
        }
        
        self.cloudSlot.scanRoots(isPhotosEnabled: isPhotosEnabled, onFoundMainShare: withMainShare, onMainShareNotFound: {
            // if there are no main shares - try to create a Volume, but only once
            self.cloudSlot.createVolume(signersKit: signersKit) { createVolumeResult in
                switch createVolumeResult {
                case .failure(let error):
                    withMainShare(.failure(error))
                case .success:
                    self.cloudSlot?.scanRoots(isPhotosEnabled: isPhotosEnabled, onFoundMainShare: withMainShare, onMainShareNotFound: {
                        completion(.failure(CloudSlot.Errors.noSharesAvailable))
                    })
                }
            }
        })
    }
    
    // things we need to do on every start
    public func start(runEventsProcessor: Bool) {
        // clean old events from EventsConveyor storage
        try? self.eventsConveyor.persistentQueue.periodicalCleanup()
        
        featureFlags.start { _ in } // start with event system, error is ignored, we will use cache or defaults
        offlineSaver?.start()
        
        intializeEventsSystem()
        if runEventsProcessor {
            runEventsSystem()
        }

        if let uid = self.sessionVault.sessionCredential?.UID {
            self.networking.setSessionUID(uid: uid)
        }
    }
    
    // stop recurrent work without cleanup
    @objc public func stop() {
        featureFlags.stop()  // pause with event system
        pauseEventsSystem()
        offlineSaver?.cleanUp()
    }
    
    public func refreshUserInfoAndAddresses() async throws {
        _ = try await withCheckedThrowingContinuation { continuation in
            self.addressManager.fetchAddresses(continuation.resume(with:))
        }
    }
    
    @available(*, deprecated, message: "Only used in tests")
    func updateUserInfo(_ handler: @escaping (Result<UserInfo, Error>) -> Void) {
        self.addressManager.fetchUserInfo { [weak self] in
            switch $0 {
            case .failure(let error):
                handler(.failure(error))
            case .success(let user):
                guard let info = self?.sessionVault.getUserInfo() else {
                    // this may happen if the app is locked before the response arrives
                    return
                }
                self?.sessionVault.storeUser(user)
                handler(.success(info))
            }
        }
    }

    public func moveToMainContext<T: NSManagedObject>(_ object: T) -> T {
        storage.moveToMainContext(object)
    }
}
