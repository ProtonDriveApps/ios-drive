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
import PDClient
import ProtonCoreKeymaker
import ProtonCoreNetworking
import Combine

@available(iOSApplicationExtension 15.0, *)
@available(macOS 13.0, *)
public class PostLoginServices {
    public typealias AdditionalSetupBlock = () async throws -> Void
    
    public let tower: Tower
    private let initialServices: InitialServices
    private var storage: StorageManager { tower.storage }
    private var syncStorage: SyncStorageManager? { tower.syncStorage }
    private let activityObserver: ((NSUserActivity) -> Void)

    public let metadataDBWasRecreated: Bool

    var observations: Set<AnyCancellable> = []
    
    public init(initialServices: InitialServices,
                appGroup: SettingsStorageSuite,
                storage: StorageManager? = nil,
                syncStorage: SyncStorageManager? = nil,
                eventObservers: [EventsListener] = [],
                eventProcessingMode: DriveEventsLoopMode,
                eventLoopInterval: Double,
                uploadVerifierFactory: UploadVerifierFactory,
                activityObserver: @escaping ((NSUserActivity) -> Void))
    {
        self.initialServices = initialServices
        self.activityObserver = activityObserver
        
        let towerStorage = storage ?? StorageManager(suite: appGroup, sessionVault: initialServices.sessionVault)
        self.metadataDBWasRecreated = StorageManager.metadataDBWasRecreated

        #if os(macOS)
        let towerSyncStorage: SyncStorageManager = syncStorage ?? SyncStorageManager(suite: appGroup)
        let populatedStateController: PopulatedStateControllerProtocol = PopulatedStateControllerStub()
        #else
        let towerSyncStorage: SyncStorageManager? = nil
        let populatedStateController: PopulatedStateControllerProtocol = PopulatedStateController()
        #endif

        self.tower = Tower(storage: towerStorage,
                           syncStorage: towerSyncStorage,
                           eventStorage: EventStorageManager(suiteUrl: appGroup.directoryUrl),
                           appGroup: appGroup,
                           mainKeyProvider: initialServices.sessionVault.mainKeyProvider,
                           sessionVault: initialServices.sessionVault,
                           sessionCommunicator: initialServices.sessionRelatedCommunicator,
                           authenticator: initialServices.authenticator,
                           clientConfig: initialServices.clientConfig,
                           network: initialServices.networkService,
                           eventObservers: eventObservers,
                           eventProcessingMode: eventProcessingMode,
                           eventLoopInterval: eventLoopInterval,
                           uploadVerifierFactory: uploadVerifierFactory,
                           localSettings: initialServices.localSettings,
                           populatedStateController: populatedStateController,
                           connectionStateResource: initialServices.connectionStateResource
        )

        self.initialServices.networkClient.publisher(for: \.currentActivity)
            .dropFirst() // ignore the current value
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] activity in self?.currentActivityChanged(activity) })
            .store(in: &observations)
    }
    
    public func resetMOCs() {
        storage.mainContext.performAndWait {
            storage.mainContext.reset()
        }
        storage.backgroundContext.performAndWait {
            storage.backgroundContext.reset()
        }
    }
    
    #if os(iOS)
    public func signOut() {
        Task {
            await signOutAsync(notify: true)
        }
    }
    
    // exposed for tests
    public func signOutAsync(notify: Bool) async {
        // close Tower properly, close session on BE and remove credentials from session vault
        await tower.signOut(cacheCleanupStrategy: .cleanEverything)
        // disconnect FileProvider extensions
        try? await signOutFileProvider()
        // destroy mainKey in Keychain
        initialServices.mainKeyProvider.wipeMainKey()

        cleanAPIServiceSessionAndNotifyIfNeeded(notify)
    }
    
    private func signOutFileProvider() async throws {
        try? await PostLoginServices.removeFileProvider()
    }
    
    private func cleanAPIServiceSessionAndNotifyIfNeeded(_ notify: Bool) {
        // remove session from networking object when signing out
        initialServices.networkService.sessionUID = ""
        
        if notify {
            // notify cross-process observers
            DarwinNotificationCenter.shared.postNotification(.DidLogout)
        }
    }
    #endif
    
    public func onLaunchAfterSignIn() {
        Log.trace()
        tower.start(options: [])
    }

    private func currentActivityChanged(_ activity: NSUserActivity) {
        Log.info("event: \(activity.activityType)", domain: .events)
        self.activityObserver(activity)
    }
}
