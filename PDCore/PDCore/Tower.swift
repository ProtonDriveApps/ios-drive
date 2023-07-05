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
import os.log
import CoreData
import PDClient
import PMEventsManager
import ProtonCore_Authentication
import ProtonCore_Services
import ProtonCore_Keymaker
import ProtonCore_Networking
import ProtonCore_DataModel

typealias ResponseError = ProtonCore_Networking.ResponseError

public class Tower: NSObject, LogObject {
    typealias CoreEventLoopManager = EventPeriodicScheduler<GeneralEventsLoopWithProcessor, DriveEventsLoop>
    public static var osLog: OSLog = OSLog(subsystem: "PDCore", category: "Tower")

    public let fileUploader: FileUploader
    public let fileImporter: FileImporter
    public let revisionImporter: RevisionImporter
    public let downloader: Downloader!
    public let uiSlot: UISlot!
    public let cloudSlot: CloudSlot!
    public let fileSystemSlot: FileSystemSlot!
    public let sessionVault: SessionVault
    public let localSettings: LocalSettings
    public let paymentsStorage: PaymentsSecureStorage
    public let offlineSaver: OfflineSaver!

    public let api: PDClient.APIService
    public let storage: StorageManager
    public let client: PDClient.Client
    internal let sharingManager: SharingManager
    internal let thumbnailLoader: CancellableThumbnailLoader
    internal let generalSettings: GeneralSettings
    
    // internal for Tower+Events.swift
    internal let eventsConveyor: EventsConveyor
    internal let coreEventManager: CoreEventLoopManager
    internal let eventObservers: [EventsListener]
    internal let eventProcessingMode: DriveEventsLoopMode
    
    private let addressManager: AddressManager
    private let networking: PMAPIService
    private let authenticator: Authenticator
    
    public init(storage: StorageManager,
                eventStorage: EventStorageManager,
                appGroup: SettingsStorageSuite,
                mainKeyProvider: Keymaker,
                sessionVault: SessionVault,
                authenticator: Authenticator,
                clientConfig: PDClient.APIService.Configuration,
                network: PMAPIService,
                eventObservers: [EventsListener],
                eventProcessingMode: DriveEventsLoopMode,
                networkSpy: DriveAPIService? = nil)
    {
        self.storage = storage
        self.uiSlot = UISlot(storage: storage)
        
        let localSettings  = LocalSettings(suite: appGroup)
        self.localSettings = localSettings
        self.generalSettings = GeneralSettings(mainKeyProvider: mainKeyProvider, network: network, localSettings: localSettings)
        self.sessionVault = sessionVault
        self.api = APIService(configuration: clientConfig)
        
        self.networking = network
        self.addressManager = AddressManager(authenticator: authenticator, sessionVault: sessionVault)
        self.authenticator = authenticator
        
        let client = Client(credentialProvider: self.sessionVault, service: api, networking: networkSpy ?? network)
        client.errorMonitor = ErrorMonitor(ConsoleLogger.shared?.logDeserializationErrors)
        self.client = client

        let cloudSlot = CloudSlot(client: client, storage: storage, signersKitFactory: sessionVault)
        self.cloudSlot = cloudSlot

        let endpointFactory = DriveEndpointFactory(service: api, credentialProvider: sessionVault)
        let downloader = Downloader(cloudSlot: cloudSlot, endpointFactory: endpointFactory)
        self.downloader = downloader
        
        self.offlineSaver = OfflineSaver(clientConfig: clientConfig, storage: storage, downloader: downloader)
        self.sharingManager = SharingManager(cloudSlot: cloudSlot, sessionVault: sessionVault)

        // Thumbnails
        self.thumbnailLoader = ThumbnailLoaderFactory().makeFileThumbnailLoader(storage: storage, cloudSlot: cloudSlot)

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        self.fileSystemSlot = FileSystemSlot(baseURL: documents, storage: self.storage)
        
        // Events
        let paymentsStorage = PaymentsSecureStorage(mainKeyProvider: mainKeyProvider)
        self.paymentsStorage = paymentsStorage
        
        self.eventsConveyor = EventsConveyor(storage: eventStorage)
        self.eventObservers = eventObservers
        self.eventProcessingMode = eventProcessingMode
        self.coreEventManager = Self.makeCoreEventsSystem(appGroup: appGroup, sessionVault: sessionVault, generalSettings: generalSettings, paymentsSecureStorage: paymentsStorage, network: network)
        
        // Files
        self.fileImporter = CoreDataFileImporter(moc: cloudSlot.moc, signersKitFactory: sessionVault)
        self.revisionImporter = CoreDataRevisionImporter(signersKitFactory: sessionVault)

        let fileUploadFactory: FileUploadOperationsProviderFactory
        #if os(macOS)
        fileUploadFactory = DiscreteFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, apiService: api)
        #else
        if Constants.runningInExtension {
            fileUploadFactory = StreamFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, apiService: api)
        } else {
            fileUploadFactory = iOSFileUploadOperationsProviderFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, apiService: api)
        }
        #endif

        self.fileUploader = FileUploader(
            fileUploadFactory: fileUploadFactory.make(),
            storage: storage,
            sessionVault: sessionVault,
            moc: storage.backgroundContext
        )

        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadCache), name: .nukeCache, object: nil)
    }
    
    private func destroyCache() {
        discardEventsPolling()
        
        downloader.cancelAll()
        thumbnailLoader.cancelAll()
        fileUploader.cancelAll()
        offlineSaver.cleanUp()
        fileSystemSlot.clear()
        localSettings.cleanUp()
        generalSettings.cleanUp()

        storage.clearUp()

        PDFileManager.destroyPermanents()
        PDFileManager.destroyCaches()

        URLCache.shared.removeAllCachedResponses()
    }
    
    /// Clears local cache without clearing the user session
    @objc private func reloadCache() {
        destroyCache()
        NotificationCenter.default.post(name: .restartApplication, object: nil)
    }

    public func signOut() {
        destroyCache()
        logout() // Before sessionVault clean to have the credential
        sessionVault.signOut()
    }

    private func logout() {
        ConsoleLogger.shared?.log("Attempting logout", osLogType: Tower.self)
        guard let coreCredential = sessionVault.credential else { return }
        let credential = Credential(coreCredential)

        authenticator.closeSession(credential) { result in
            switch result {
            case .success:
                ConsoleLogger.shared?.log("Logout successful", osLogType: Tower.self)
            case .failure:
                ConsoleLogger.shared?.log("Logout failed", osLogType: Tower.self)
            }
        }
    }
    
    // things we need to do once
    public func onFirstBoot(_ completion: @escaping (Result<Void, Error>) -> Void) {
        if let addresses = sessionVault.addresses, sessionVault.userInfo != nil {
            firstBoot(with: addresses, completion)
        } else {
            self.addressManager.fetchAddresses { [weak self] in
                guard case Result.success(let addresses) = $0 else {
                    return completion( $0.flatMap { _ in .success(Void()) })
                }
                self?.firstBoot(with: addresses, completion)
            }
        }
    }

    private func firstBoot(with addresses: [Address], _ completion: @escaping (Result<Void, Error>) -> Void) {
        let activeAddresses = addresses.filter({ !$0.keys.isEmpty })
        guard let primaryAddress = activeAddresses.first else {
            return completion(.failure(AddressManager.Errors.noPrimaryAddress))
        }

        guard let signersKit = try? SignersKit(address: primaryAddress, sessionVault: self.sessionVault) else {
            return completion(.failure(SignersKit.Errors.noAddressWithRequestedSignature))
        }
        
        self.generalSettings.fetchUserSettings() // opportunistic, no need to abort the boot if this call fails

        let withMainShare: (Result<Share, Error>) -> Void = { sharesResult in
            switch sharesResult {
            case let .failure(error):
                completion(.failure(error))
            case .success:
                completion(.success(Void()))
            }
        }

        self.cloudSlot.scanRoots(onFoundMainShare: withMainShare, onMainShareNotFound: {
            // if there are no main shares - try to create a Volume, but only once
            self.cloudSlot.createVolume(signersKit: signersKit) { createVolumeResult in
                switch createVolumeResult {
                case .failure(let error):
                    withMainShare(.failure(error))
                case .success:
                    self.cloudSlot?.scanRoots(onFoundMainShare: withMainShare, onMainShareNotFound: {
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
        
        offlineSaver.start()
        
        intializeEventsSystem()
        if runEventsProcessor {
            runEventsSystem()
        }

        if let uid = self.sessionVault.credential?.UID {
            self.networking.setSessionUID(uid: uid)
        }
    }
    
    // stop recurrent work without cleanup
    @objc public func stop() {
        pauseEventsSystem()
        offlineSaver.cleanUp()
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
