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

import Combine
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
import ProtonCorePayments

typealias ResponseError = ProtonCoreNetworking.ResponseError

public class Tower: NSObject {
    typealias CoreEventLoopManager = EventPeriodicScheduler<GeneralEventsLoopWithProcessor, DriveEventsLoop>

    public let fileUploader: FileUploader
    public let fileImporter: FileImporter
    public let revisionImporter: RevisionImporter
    public let uploadVerifierFactory: UploadVerifierFactory
    public let downloader: Downloader!
    public let refresher: RefreshingNodesServiceProtocol
    public let uiSlot: UISlot!
    public let cloudSlot: CloudSlotProtocol!
    public let fileSystemSlot: FileSystemSlot!
    public let sessionVault: SessionVault
    public let sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions
    public let localSettings: LocalSettings
    public let paymentsStorage: PaymentsSecureStorage
    public var offlineSavers = [OfflineSaverProtocol]()
    public let connectionStateResource: ConnectionStateResource
    public let performanceMetricsController: PerformanceMetricsControllerProtocol?
    public let parentIDFetcher: NodeParentIDFetcher

    public var photoUploader: FileUploader?

    public let api: PDClient.APIService
    public let storage: StorageManager
    public let syncStorage: SyncStorageManager?
    public let client: PDClient.Client
    public let rateLimitGate: RateLimitGate
    public let addressManager: AddressManager
    internal var thumbnailLoader: CancellableThumbnailLoader
    public let generalSettings: GeneralSettings
    public let featureFlags: FeatureFlagsRepository
    public let parallelEncryption: Bool
    public let entitlementsManager: EntitlementsManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    public let uploadedBytesCounterResource: BytesCounterResource
    public let clientConfiguration: PDClient.APIService.Configuration

    // internal for Tower+Events.swift
    var externalInvitationConverter: ExternalInvitationConvertProtocol?
    var nodeTreeOperator: NodeTreeOperatorProtocol?
    var storageSuite: SettingsStorageSuite
    var mainVolumeEventsConveyor: EventsConveyor?
    var volumeEventsReferenceStorage: VolumeEventsReferenceStorageProtocol?
    let coreEventManager: CoreEventLoopManager
    let eventObservers: [EventsListener]
    let eventProcessingMode: DriveEventsLoopMode
    public let eventStorageManager: EventStorageManager
    let eventsTimingController: EventLoopsTimingController
    let volumeIdsController: VolumeIdsControllerProtocol
    public var sharedVolumeIdsController: SharedVolumeIdsController {
        volumeIdsController
    }
    @ThreadSafe private var isStopped = false

    // SDK
    private var sdkNodeOperationPerformer: SDKNodeOperationPerformer?
    private var sdkFileUploader: SDKFileUploaderProtocol?
    private var sdkFileDownloader: SDKFileDownloaderProtocol?
    private var sdkThumbnailsDownloaderForFiles: SDKThumbnailsDownloaderProtocol?
    private var sdkThumbnailsDownloaderForPhotos: SDKThumbnailsDownloaderProtocol?
    private var sdkPhotoDownloader: SDKFileDownloaderProtocol?
    private var sdkPhotoUploader: SDKFileUploaderProtocol?
    public private(set) var sdkRevisionUploader: SDKRevisionUploaderProtocol?
    public private(set) var sdkCacheProvider: SDKCacheProvider
    public private(set) var sdkEncryptionKeyProvider: SDKEncryptionKeyProvider?

    // QA only
    public static let shouldFetchEventsStorageKey = "shouldFetchEvents"
    @SettingsStorage(shouldFetchEventsStorageKey) public var shouldFetchEvents: Bool? {
        didSet {
            guard oldValue != shouldFetchEvents, let shouldFetchEvents else { return }
            if shouldFetchEvents {
                runEventsSystem()
            } else {
                pauseEventsSystem()
            }
        }
    }

    public let networking: PMAPIService
    private let authenticator: Authenticator
    public let contactAdapter = ContactAdapter()

    // Clean up
    public var cleanUpController: CleanUpEventController {
        cleanUpStartController
    }
    private let cleanUpStartController: CleanUpStartController

    // swiftlint:disable:next function_body_length
    public init(storage: StorageManager,
                syncStorage: SyncStorageManager? = nil,
                eventStorage: EventStorageManager,
                appGroup: SettingsStorageSuite,
                mainKeyProvider: MainKeyProvider,
                sessionVault: SessionVault,
                sessionCommunicator: SessionRelatedCommunicatorBetweenMainAppAndExtensions,
                authenticator: Authenticator,
                clientConfig: PDClient.APIService.Configuration,
                network: PMAPIService,
                eventObservers: [EventsListener],
                eventProcessingMode: DriveEventsLoopMode,
                eventLoopInterval: Double,
                networkSpy: DriveAPIService? = nil,
                uploadVerifierFactory: UploadVerifierFactory,
                localSettings: LocalSettings,
                populatedStateController: PopulatedStateControllerProtocol,
                connectionStateResource: ConnectionStateResource
    ) {
        Log.trace("eventLoopInterval: \(eventLoopInterval)")

        self.storage = storage
        self.syncStorage = syncStorage
        self.uiSlot = UISlot(storage: storage)

        self.localSettings = localSettings
        self.generalSettings = GeneralSettings(
            mainKeyProvider: mainKeyProvider,
            network: network,
            localSettings: localSettings,
            connectionStateResource: connectionStateResource
        )
        self.sessionVault = sessionVault
        self.sessionCommunicator = sessionCommunicator
        clientConfiguration = clientConfig
        self.featureFlags = FeatureFlagsRepositoryFactory().makeRepository(
           configuration: clientConfig,
           networking: network,
           store: localSettings
       )
        self.api = APIServiceFactory().makeService(configuration: clientConfig, featureFlags: featureFlags)

        self.networking = network
        self.addressManager = AddressManager(authenticator: authenticator, sessionVault: sessionVault)
        self.authenticator = authenticator

        let rateLimitGate = RateLimitGate()
        self.rateLimitGate = rateLimitGate
        let client = Client(credentialProvider: self.sessionVault, service: api, networking: networkSpy ?? network, rateLimitGate: rateLimitGate)
        client.errorMonitor = ErrorMonitor(Log.deserializationErrors)
        self.client = client
        self.connectionStateResource = connectionStateResource

        self.parentIDFetcher = NodeParentIDFetcher(storage: storage)

        #if os(macOS)
        self.cloudSlot = CloudSlot(client: client, storage: storage, sessionVault: sessionVault, parentIDFetcher: parentIDFetcher)
        self.performanceMetricsController = nil
        #else
        let legacyCloudSlot = CloudSlot(client: client, storage: storage, sessionVault: sessionVault, parentIDFetcher: parentIDFetcher)
        self.cloudSlot = VolumeDBCloudSlot(storage: storage, apiService: api, client: client, cloudSlot: legacyCloudSlot)
        self.performanceMetricsController = PerformanceMetricsController()
        #endif

        let endpointFactory = DriveEndpointFactory(service: api, credentialProvider: sessionVault)
        let downloader = Downloader(
            cloudSlot: cloudSlot,
            storage: storage,
            endpointFactory: endpointFactory,
            bytesCounterResource: ThreadSafeBytesCounterResource()
        )
        self.downloader = downloader
        self.entitlementsManager = EntitlementsManager(
            client: client,
            store: EntitlementsStore(localSettings: localSettings)
        )

        self.thumbnailLoader = ThumbnailLoaderFactory().makeFileThumbnailLoader(
            tower: nil,
            storage: storage,
            cloudSlot: cloudSlot,
            client: client,
            performanceMetricsController: performanceMetricsController
        )

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        self.fileSystemSlot = FileSystemSlot(baseURL: documents, storage: self.storage, syncStorage: self.syncStorage)

        // Events
        let paymentsStorage = PaymentsSecureStorage(mainKeyProvider: mainKeyProvider)
        self.paymentsStorage = paymentsStorage

        storageSuite = appGroup
        self.eventObservers = eventObservers
        self.eventProcessingMode = eventProcessingMode
        volumeIdsController = VolumeIdsController()
        let eventsFactory = EventsFactory()
        #if os(iOS)
        eventsTimingController = eventsFactory.makeMultipleVolumesTimingController(volumeIdsController: volumeIdsController)
        #else
        eventsTimingController = eventsFactory.makeSingleVolumeTimingController(interval: eventLoopInterval)
        #endif
        self.coreEventManager = eventsFactory.makeCoreEventsSystem(appGroup: appGroup, sessionVault: sessionVault, generalSettings: generalSettings, paymentsSecureStorage: paymentsStorage, network: network, timingController: eventsTimingController, contactAdapter: contactAdapter, entitlementsManager: entitlementsManager)
        eventStorageManager = eventStorage

        self.uploadVerifierFactory = uploadVerifierFactory

        // Files
        self.fileImporter = CoreDataFileImporter(moc: storage.backgroundContext, signersKitFactory: sessionVault, uploadClientUIDProvider: sessionVault)
        self.revisionImporter = CoreDataRevisionImporter(signersKitFactory: sessionVault, uploadClientUIDProvider: sessionVault)

        uploadedBytesCounterResource = ThreadSafeBytesCounterResource()
        #if os(macOS)
        parallelEncryption = true
        self.fileUploader = FileUploader(
            fileUploadFactory: DiscreteFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, verifierFactory: uploadVerifierFactory, apiService: api, client: client, parallelEncryption: parallelEncryption, uploadedBytesCounterResource: uploadedBytesCounterResource).make(),
            filecleaner: cloudSlot,
            moc: storage.backgroundContext
        )
        #else
        parallelEncryption = false
        if Constants.runningInExtension {
            self.fileUploader = FileUploader(
                fileUploadFactory: StreamFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, verifierFactory: uploadVerifierFactory, apiService: api, client: client, parallelEncryption: parallelEncryption, uploadedBytesCounterResource: uploadedBytesCounterResource).make(),
                filecleaner: cloudSlot,
                moc: storage.backgroundContext
            )
        } else {
            self.fileUploader = MyFilesFileUploader(
                fileUploadFactory: iOSFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, verifierFactory: uploadVerifierFactory, apiService: api, client: client, parallelEncryption: parallelEncryption, uploadedBytesCounterResource: uploadedBytesCounterResource).make(),
                filecleaner: cloudSlot,
                moc: storage.backgroundContext
            )
        }
        #endif

        cleanUpStartController = CleanUpController()

        refresher = RefreshingNodesService(downloader: downloader, coreEventManager: coreEventManager, storage: storage, sessionVault: sessionVault)

        sdkCacheProvider = SDKCacheProvider(groupContainerDirectory: appGroup.directoryUrl)

        self.sdkEncryptionKeyProvider = SDKEncryptionKeyProvider()

        super.init()
        
        if Constants.buildType.isQaOrBelow {
            _shouldFetchEvents.configure(with: .group(named: Constants.appGroup))
        }

        #if os(macOS)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadCache), name: .nukeCache, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cleanLogs), name: .nukeLogs, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadCacheExcludingEvents), name: .nukeCacheExcludingEvents, object: nil)

        // iOS uses `subscribeToCleanUpNotifications`
        #endif
    }

    deinit {
        Log.info("Deinitializing Tower", domain: .application)
    }

    public func cleanUpLockedVolumeIfNeeded(using domainManager: DomainOperationsServiceProtocol) async throws {
        try await Self.cleanUpLockedVolumeIfNeeded(coreEventManager: coreEventManager,
                                                   storage: storage,
                                                   cloudSlot: cloudSlot,
                                                   sessionVault: sessionVault,
                                                   domainManager: domainManager)
    }

    static func cleanUpLockedVolumeIfNeeded(coreEventManager: CoreEventLoopManager,
                                            storage: StorageManager,
                                            cloudSlot: CloudSlotProtocol,
                                            sessionVault: SessionVault,
                                            domainManager: DomainOperationsServiceProtocol) async throws {
        func onVolumeBeingLocked() async throws {
            try await domainManager.removeAllDomains()
            await Self.cleanUpEventsAndMetadata(cleanupStrategy: .cleanEverything, coreEventManager: coreEventManager, storage: storage)
        }

        // How we identify the volume we have in the DB is locked on BE:
        // 1. There is a root in the DB — if there's no root, we will bootstrap later and learn whether the volume is locked or not this way
        // 2. There is root is impossible to decrypt — this is an indicator there was a password reset.
        //    We double-check it by fetching volumes, shares and root from the BE.
        // If there is no share, no root or no volume on BE, we need to clean up the local state.
        // Alternatively, if the root returned by BE is different than our local DB root, we must clean up the local state as well.
        // We'll fetch it later, during bootstrap.
        let moc = storage.backgroundContext
        guard let root = Self.fetchRootFolder(sessionVault: sessionVault, storage: storage, in: moc) else { return }
        do {
            _ = try await moc.perform { try root.decryptName() }
        } catch {
            //  The default value was false
            guard let mainShare = try await cloudSlot.scanRootsAsync(isPhotosEnabled: false, moc: moc) else {
                // no volume, no main share returned from BE
                try await onVolumeBeingLocked()
                return
            }

            var volumeIsLocked: Bool = false
            await moc.perform {
                if let fetchedRoot = mainShare.root,
                   let volume = mainShare.volume,
                   fetchedRoot.identifierWithinManagedObjectContext == root.identifierWithinManagedObjectContext {
                    volumeIsLocked = volume.state == .locked
                } else {
                    volumeIsLocked = true
                }
            }
            guard volumeIsLocked else { return }
            try await onVolumeBeingLocked()
        }
    }

    public func bootstrap() async throws {
        let config: FirstBootConfiguration = .init(isPhotoEnabled: false, isTabSettingsRequested: false)
        try await onFirstBoot(config: config)
    }

    public func bootstrapIfNeeded() async throws {
        let needsBootstrap: Bool = {
            let context = storage.synchronousContextPool.acquire()
            defer { storage.synchronousContextPool.relinquish(context) }
            return rootFolderAvailable(moc: context) == false
        }()
        guard needsBootstrap else { return }
        Log.info("Bootstrap needed", domain: .application)
        try await bootstrap()
    }

    public func cleanUpEventsAndMetadata(cleanupStrategy: CacheCleanupStrategy) async {
        await Self.cleanUpEventsAndMetadata(cleanupStrategy: cleanupStrategy, coreEventManager: coreEventManager, storage: storage)
    }

    static func cleanUpEventsAndMetadata(
        cleanupStrategy: CacheCleanupStrategy, coreEventManager: CoreEventLoopManager, storage: StorageManager
    ) async {
        if cleanupStrategy.shouldCleanEvents {
            discardEventsPolling(for: coreEventManager)
        }
        if cleanupStrategy.shouldCleanMetadata {
            await storage.cleanUp()

            let groupContainerDirectory = SettingsStorageSuite.group(named: Constants.appGroup).directoryUrl
            SDKCacheProvider(groupContainerDirectory: groupContainerDirectory).cleanUp()
        }
    }

    #if os(iOS)
    @MainActor
    public func signOut(cacheCleanupStrategy: CacheCleanupStrategy) async {
        if let userId = sessionVault.userInfo?.ID {
            ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.resetFlags(for: userId)
            ProtonCoreFeatureFlags.FeatureFlagsRepository.shared.clearUserId()
        }
        await destroyCache(strategy: cacheCleanupStrategy)
        featureFlags.stop() // stop when logged out
        await Self.removeSessionInBE(sessionVault: sessionVault, authenticator: authenticator) // Before sessionVault clean to have the credential
        sessionVault.signOut()
        sessionCommunicator.clearStateOnSignOut()
    }

    public func set(sdkFileUploader: SDKFileUploaderProtocol?) {
        self.sdkFileUploader = sdkFileUploader
    }

    public func set(sdkFileDownloader: SDKFileDownloaderProtocol) {
        self.sdkFileDownloader = sdkFileDownloader
    }

    public func set(sdkNodeOperationPerformer: SDKNodeOperationPerformer) {
        self.sdkNodeOperationPerformer = sdkNodeOperationPerformer
    }

    public func set(treeTrashHandler: NodeTreeTrashHandlerProtocol) {
        if let slot = cloudSlot as? VolumeDBCloudSlot {
            slot.set(nodeTreeTrashHandler: treeTrashHandler)
        }
    }

    public func set(sdkThumbnailsDownloaderForFiles: SDKThumbnailsDownloaderProtocol) {
        self.sdkThumbnailsDownloaderForFiles = sdkThumbnailsDownloaderForFiles
        thumbnailLoader = ThumbnailLoaderFactory().makeFileThumbnailLoader(
            tower: self,
            storage: storage,
            cloudSlot: cloudSlot,
            client: client,
            performanceMetricsController: performanceMetricsController
        )
    }

    public func set(sdkThumbnailsDownloaderForPhotos: SDKThumbnailsDownloaderProtocol) {
        self.sdkThumbnailsDownloaderForPhotos = sdkThumbnailsDownloaderForPhotos
    }

    public func set(sdkRevisionUploader: SDKRevisionUploaderProtocol) {
        self.sdkRevisionUploader = sdkRevisionUploader
    }

    public func set(sdkPhotoDownloader: SDKFileDownloaderProtocol) {
        self.sdkPhotoDownloader = sdkPhotoDownloader
    }

    public func set(sdkPhotoUploader: SDKFileUploaderProtocol) {
        self.sdkPhotoUploader = sdkPhotoUploader
    }
    #endif // os(iOS)

    public func getSdkThumbnailsDownloaderForFiles() -> SDKThumbnailsDownloaderProtocol? {
        guard featureFlags.isEnabled(flag: .driveiOSSDKDownloadMain) else { return nil }
        return sdkThumbnailsDownloaderForFiles
    }

    public func getSdkThumbnailsDownloaderForPhotos() -> SDKThumbnailsDownloaderProtocol? {
        guard featureFlags.isEnabled(flag: .driveiOSSDKDownloadPhoto) else { return nil }
        return sdkThumbnailsDownloaderForPhotos
    }

    public func getSdkFileDownloader() -> SDKFileDownloaderProtocol? {
        guard featureFlags.isEnabled(flag: .driveiOSSDKDownloadMain) else { return nil }
        return sdkFileDownloader
    }

    public func getSdkFileUploader() -> SDKFileUploaderProtocol? {
        guard featureFlags.isEnabled(flag: .driveiOSSDKUploadMain) else { return nil }
        return sdkFileUploader
    }

    public func getSdkNodeOperationPerformer() -> SDKNodeOperationPerformer? {
        guard featureFlags.isEnabled(flag: .driveiOSSDKNodeOperations) else { return nil }
        return sdkNodeOperationPerformer
    }

    public func getSdkPhotoDownloader() -> SDKFileDownloaderProtocol? {
        guard featureFlags.isEnabled(flag: .driveiOSSDKDownloadPhoto) else { return nil }
        return sdkPhotoDownloader
    }

    public func getSdkPhotoUploader() -> SDKFileUploaderProtocol? {
        // Feature flag is not checked here to avoid disrupting the backup flow
        // PhotoFeederPreprocessor handles feature flag logic
        return sdkPhotoUploader
    }

    @MainActor
    public func destroyCache(strategy cacheCleanupStrategy: CacheCleanupStrategy) async {
        photoUploader?.didSignOut = true
        photoUploader?.cancelAllOperations()
        fileUploader.didSignOut = true
        fileUploader.cancelAllOperations()
        await sdkFileUploader?.cancelAll()
        performanceMetricsController?.reset()

        if cacheCleanupStrategy.shouldCleanEvents {
            Self.discardEventsPolling(for: coreEventManager)
        }

        /// The clean up follows a certain order. Right now any subscriber of `cleanUpController` will execute their work before any other cleanup (storage, vault, etc).
        /// There might be more coordination needed in the future, think about how to indicate which domain of resources should react to a notification.
        /// Tips: (parametrizing `start` function / multiple functions - one per domain / multiple cleanup controllers - one per domain)...
        cleanUpStartController.start()

        downloader.cancelAll()
        sdkFileDownloader?.cancelAll()
        sdkCacheProvider.cleanUp()
        sdkEncryptionKeyProvider?.removeEncryptionKey()
        offlineSavers.forEach { $0.cleanUp() }

        thumbnailLoader.cancelAll()
        fileSystemSlot.clear()
        localSettings.cleanUp(cleanUserSpecificSettings: cacheCleanupStrategy.shouldCleanUserSpecificSettings)
        generalSettings.cleanUp()

        if cacheCleanupStrategy.shouldCleanMetadata {
            await storage.cleanUp()
        }
        await syncStorage?.cleanUp()

        PDFileManager.destroyPermanents()
        PDFileManager.destroyCaches()

        #if os(macOS)
        UserDefaults.standard.dictionaryRepresentation().forEach { key, _ in
            UserDefaults.standard.removeObject(forKey: key)
        }
        #elseif os(iOS)
        PDFileManager.destroyFPCaches()
        var keys: Set<String> = Set(UserDefaults.standard.dictionaryRepresentation().keys)
        if !cacheCleanupStrategy.shouldCleanBackupCache {
            let excludedKeys = SettingsStorageKey.keysExcludedFromWiping.map { $0.value }
            keys.subtract(excludedKeys)
        }
        keys.subtract(AppDefaultKey.keysExcludedFromWiping.map(\.value))
        keys.forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
        #endif
        URLCache.shared.removeAllCachedResponses()
    }

    public static func removeSessionInBE(sessionVault: SessionVault, authenticator: Authenticator) async {
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
                    Log.error(error: error, domain: .networking)
                    continuation.resume(returning: Void())
                }
            }
        }
    }

    public struct StartOptions: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let runEventsProcessor = StartOptions(rawValue: 1 << 0)
        public static let initializeAllVolumes = StartOptions(rawValue: 1 << 1)
    }

    // things we need to do on every start
    public func start(options: StartOptions) {
        Log.trace()
        
        // Clean old events from Events Storage
        // Cleans all events no matter the volumeId
        try? eventStorageManager.periodicalCleanup()

        #if os(macOS)
        // iOS client fetch core FF in initialService
        featureFlags.start { _ in } // start with event system, error is ignored, we will use cache or defaults
        #endif
        offlineSavers.forEach { $0.start() }

        // Events
        let includeAllVolumes = options.contains(.initializeAllVolumes)
        do {
            try intializeEventsSystem(includeAllVolumes: includeAllVolumes)
        } catch {
            Log.error("Events system failed to initialize", error: nil, domain: .events)
        }
        if options.contains(.runEventsProcessor) {
            runEventsSystem()
        }

        if let uid = self.sessionVault.sessionCredential?.UID {
            self.networking.setSessionUID(uid: uid)
        }
    }

    // stop recurrent work without cleanup
    @objc public func stop() {
        isStopped = true
        featureFlags.stop()  // pause with event system
        pauseEventsSystem()
        offlineSavers.forEach { $0.cleanUp() }
    }

    public func resume() {
        guard isStopped else { return }
        Task {
           try await featureFlags.startAsync()
        }
        coreEventManager.start()
        offlineSavers.forEach { $0.start() }
        isStopped = false
    }

    public func refreshUserInfoAndAddresses() async throws {
        _ = try await withCheckedThrowingContinuation { continuation in
            self.addressManager.fetchAddresses(continuation.resume(with:))
        }
    }

    @available(*, deprecated, message: "Only used in tests")
    public func updateUserInfo(_ handler: @escaping (Result<UserInfo, Error>) -> Void) {
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

// MARK: - things we need to do once
extension Tower {
    public func onFirstBoot(config: FirstBootConfiguration) async throws {
        let addresses = try await getAddress()

        let signersKit = try makeSignersKit(addresses: addresses)
        // initial fetching during login, error is ignored, we will use cache or defaults
        try? await featureFlags.startAsync()
        self.generalSettings.fetchUserSettings() // opportunistic, no need to abort the boot if this call fails
        do {
            let context = storage.synchronousContextPool.acquire()
            defer { storage.synchronousContextPool.relinquish(context) }
            _ = try await prepareShare(isPhotosEnabled: config.isPhotoEnabled, signersKit: signersKit, moc: context)
        }
        if config.isTabSettingsRequested {
            let updater = TabbarSettingUpdater(
                client: client,
                featureFlags: featureFlags,
                localSettings: localSettings,
                networking: networking,
                storageManager: storage
            )
            await updater.updateTabSettingBasedOnUserPlan()
        }
    }

    func getAddress() async throws -> [Address] {
        if let addresses = sessionVault.addresses, sessionVault.userInfo != nil {
            return addresses
        } else {
            let addresses = try await self.addressManager.fetchAddressesAsync()
            return addresses
        }
    }

    private func makeSignersKit(addresses: [Address]) throws -> SignersKit {
        let activeAddresses = addresses.filter({ !$0.keys.isEmpty })
        guard let primaryAddress = activeAddresses.first else {
            throw AddressManager.Errors.noPrimaryAddress
        }

        guard let addressKey = primaryAddress.keys.first else {
            throw SignersKit.Errors.addressHasNoKeys
        }

        guard let addressPassphrase = try? sessionVault.addressPassphrase(for: addressKey) else {
            throw SignersKit.Errors.noAddressWithRequestedSignature
        }
        return SignersKit(address: primaryAddress, addressKey: addressKey, addressPassphrase: addressPassphrase)
    }

    private func prepareShare(
        isPhotosEnabled: Bool,
        signersKit: SignersKit,
        canScanAgain: Bool = true,
        moc: NSManagedObjectContext
    ) async throws -> Share {
        if let share = try await cloudSlot.scanRootsAsync(isPhotosEnabled: isPhotosEnabled, moc: moc) {
            return share
        }

        if canScanAgain {
            _ = try await cloudSlot.createVolumeAsync(signersKit: signersKit, moc: moc)
            return try await prepareShare(isPhotosEnabled: isPhotosEnabled, signersKit: signersKit, canScanAgain: false, moc: moc)
        } else {
            throw CloudSlot.Errors.noSharesAvailable
        }
    }
}

// MARK: - Notification
extension Tower {
    public func subscribeToCleanUpNotifications() {
        NotificationCenter.default.publisher(for: .nukeCache)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.reloadCache(notification: notification)
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .nukeCacheExcludingEvents)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadCacheExcludingEvents()
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .nukeLogs)
            .throttle(for: 3, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.cleanLogs()
            }
            .store(in: &cancellables)
    }

    /// Clears local cache without clearing the user session
    @objc private func reloadCache(notification: Notification) {
        cancellables.removeAll()
        let reason = notification.userInfo?["reason"]
        Task {
            await destroyCache(strategy: .cleanEverythingButUserSpecificSettings)
            if let reason {
                Log.info("Tower - nuked Cache due to \(reason)", domain: .application)
            } else {
                Log.info("Tower - nuked Cache", domain: .application)
            }
            NotificationCenter.default.post(name: .restartApplication, object: nil)
        }
    }

    @objc private func reloadCacheExcludingEvents() {
        cancellables.removeAll()
        Task {
            await destroyCache(strategy: .cleanOnlyMetadataDB)
            Log.info("Tower - nuked CacheExcludingEvent", domain: .application)
            NotificationCenter.default.post(name: .restartApplication, object: nil)
        }
    }

    @objc private func cleanLogs() {
        PDFileManager.clearLogsDirectory()
        try? PDFileManager.bootstrapLogDirectory()
        Log.info("Tower - clean logs", domain: .application)
    }
}

@available(*, deprecated, message: "Remove when sharing is fully deployed")
public struct FirstBootConfiguration {
    let isPhotoEnabled: Bool
    let isTabSettingsRequested: Bool

    public init(isPhotoEnabled: Bool, isTabSettingsRequested: Bool) {
        self.isPhotoEnabled = isPhotoEnabled
        self.isTabSettingsRequested = isTabSettingsRequested
    }
}
