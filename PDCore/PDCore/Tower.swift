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

public class Tower: NSObject, LogObject {
    typealias CoreEventLoopManager = EventPeriodicScheduler<GeneralEventsLoopWithProcessor, DriveEventsLoop>
    public static var osLog: OSLog = OSLog(subsystem: "PDCore", category: "Tower")

    public let fileUploader: FileUploader
    public let downloader: Downloader!
    public let uiSlot: UISlot!
    public let cloudSlot: CloudSlot!
    public let fileSystemSlot: FileSystemSlot!
    public let sessionVault: SessionVault
    public let localSettings: LocalSettings
    public let paymentsStorage: PaymentsSecureStorage
    public let offlineSaver: OfflineSaver!

    internal let api: PDClient.APIService
    public let storage: StorageManager
    internal let client: PDClient.Client
    internal let sharingManager: SharingManager
    internal let thumbnailLoader: AsyncThumbnailLoader
    internal let generalSettings: GeneralSettings
    
    public let eventsConveyor: EventsConveyor
    public let eventProcessor: EventsProcessor
    internal let coreEventManager: CoreEventLoopManager
    
    private let addressManager: AddressManager
    private let networking: PMAPIService
    private let authenticator: Authenticator
    
    public init(storage: StorageManager,
                appGroup: SettingsStorageSuite,
                mainKeyProvider: Keymaker,
                sessionVault: SessionVault,
                authenticator: Authenticator,
                clientConfig: PDClient.APIService.Configuration,
                network: PMAPIService,
                eventObservers: [EventsListener] = [],
                processEventsLocally: Bool = true)
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
        
        let client = Client(credentialProvider: self.sessionVault, service: api, networking: networking)
        client.errorMonitor = ErrorMonitor(ConsoleLogger.shared?.logDeserializationErrors)
        self.client = client

        let signersKitFactory = SignersKitFactory(sessionVault: sessionVault)
        let cloudSlot = CloudSlot(client: client, storage: storage, signersKitFactory: signersKitFactory)
        self.cloudSlot = cloudSlot
        
        let downloader = Downloader(cloudSlot: cloudSlot)
        self.downloader = downloader
        
        self.offlineSaver = OfflineSaver(clientConfig: clientConfig, storage: storage, downloader: downloader)
        self.sharingManager = SharingManager(cloudSlot: cloudSlot)

        // Thumbnails
        let thumbnailsOperatiosFactory = LoadThumbnailOperationsFactory(store: storage, cloud: cloudSlot)
        let thumbnailLoader = AsyncThumbnailLoader(operationsFactory: thumbnailsOperatiosFactory)
        self.thumbnailLoader = thumbnailLoader
        
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        self.fileSystemSlot = FileSystemSlot(baseURL: documents, storage: self.storage)
        
        // Events
        let paymentsStorage = PaymentsSecureStorage(mainKeyProvider: mainKeyProvider)
        let (conveyor, processor) = Self.makeDriveEventsSystem(storage: storage, appGroup: appGroup, eventObservers: eventObservers, eventProviders: [cloudSlot], processLocally: processEventsLocally)
        self.paymentsStorage = paymentsStorage
        self.eventsConveyor = conveyor
        self.eventProcessor = processor
        self.coreEventManager = Self.makeCoreEventsSystem(appGroup: appGroup, sessionVault: sessionVault, generalSettings: generalSettings, paymentsSecureStorage: paymentsStorage, network: network)
        
        // Files
        let fileDraftImporter = SegmentedFileDraftImporter(storage: storage, signersKitFactory: sessionVault)
        let factory = FileUploadOperationsFactory(storage: storage, cloudSlot: cloudSlot, sessionVault: sessionVault, apiService: api)

        self.fileUploader = FileUploader(
            draftImporter: fileDraftImporter,
            fileUploadFactory: factory.makeFileUploadOperationsProvider(),
            storage: storage,
            sessionVault: sessionVault
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

        let withMainShare: (Result<Share, Error>) -> Void = { sharesResult in
            guard case Result.success(let share) = sharesResult else {
                return completion( sharesResult.flatMap { _ in .success(Void()) })
            }
            
            self.cloudSlot.scanEventsFromRemote(of: share.id) { _ in
                completion(.success(Void()))
            }
            
            // opportunistic, no need to abort the boot if this call fails
            self.generalSettings.fetchUserSettings()
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
        
        let moc = self.storage.backgroundContext
        moc.performAndWait {
            let addressIDs = self.sessionVault.addressIDs
            if let mainShare = self.storage.mainShareOfVolume(by: addressIDs, moc: moc) {
                if runEventsProcessor {
                    self.startEventsPolling(shareId: mainShare.id)
                }
                self.offlineSaver.start()
                
                if let uid = self.sessionVault.credential?.UID {
                    self.networking.setSessionUID(uid: uid)
                }
            }
        }
    }
    
    // stop recurrent work without cleanup
    @objc public func stop() {
        pauseEventsPolling()
        self.offlineSaver.cleanUp()
    }

    public var eventProcessorIsRunning: Bool {
        self.eventProcessor.isRunning
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
