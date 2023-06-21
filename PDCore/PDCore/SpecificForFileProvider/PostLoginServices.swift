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
import ProtonCore_Keymaker
import os.log
import Combine

@available(iOSApplicationExtension 15.0, *)
@available(macOS 12.0, *)
public class PostLoginServices: LogObject {
    public static var osLog: OSLog = OSLog(subsystem: "PDCore", category: "PostLoginServices")
    public typealias AdditionalSetupBlock = () -> Void
    
    public let tower: Tower
    private let initialServices: InitialServices
    private let storage: StorageManager
    private var observations: Set<AnyCancellable> = []
    
    public init(initialServices: InitialServices,
                appGroup: SettingsStorageSuite,
                storage: StorageManager? = nil,
                eventObservers: [EventsListener] = [],
                eventProcessingMode: DriveEventsLoopMode)
    {
        self.initialServices = initialServices
        self.storage = storage ?? StorageManager(suite: appGroup, sessionVault: initialServices.sessionVault)
        
        self.tower = Tower(storage: self.storage,
                           eventStorage: EventStorageManager(suiteUrl: appGroup.directoryUrl),
                           appGroup: appGroup,
                           mainKeyProvider: initialServices.keymaker,
                           sessionVault: initialServices.sessionVault,
                           authenticator: initialServices.authenticator,
                           clientConfig: initialServices.clientConfig,
                           network: initialServices.networkService,
                           eventObservers: eventObservers,
                           eventProcessingMode: eventProcessingMode)
        
        self.initialServices.networkClient.publisher(for: \.currentActivity)
            .compactMap { $0 }
            .sink(receiveValue: { [weak self] activity in self?.currentActivityChanged(activity) })
            .store(in: &observations)
    }
    
    public func onSignIn(additionalSetup: @escaping AdditionalSetupBlock) {
        tower.onFirstBoot { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                additionalSetup()
            case .failure:
                self.signOut()
            }
        }
    }
    
    public func resetMOCs() {
        self.storage.mainContext.reset()
        self.storage.backgroundContext.reset()
    }
    
    public func signOut() {
        // close Tower properly, close session on BE and remove credentials from session vault
        tower.signOut()
        
        // disconnet FileProvider extensions
        removeFileProvider()
        
        // destroy mainKey in Keychain
        initialServices.keymaker.wipeMainKey()

        // remove session from networking object when signing out
        initialServices.networkService.sessionUID = ""
        
        // notify cross-process observers
        DarwinNotificationCenter.shared.postNotification(.DidLogout)
    }
    
    public func onLaunchAfterSignIn() {
        tower.start(runEventsProcessor: false)
    }
    
    private func currentActivityChanged(_ activity: NSUserActivity) {
        ConsoleLogger.shared?.fireWarning(event: "\(activity.activityType)")
        
        switch activity {
        case PMAPIClient.Activity.logout:
            self.signOut()
            
        case PMAPIClient.Activity.trustKitFailure: break

        case PMAPIClient.Activity.humanVerification: break
        
        case PMAPIClient.Activity.forceUpgrade: break
        
        default: break
        }
    }
}
