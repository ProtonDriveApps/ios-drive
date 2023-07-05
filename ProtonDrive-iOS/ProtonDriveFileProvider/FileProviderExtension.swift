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

import FileProvider
import PDFileProvider
import PDCore
import os.log
import CoreServices
import ProtonCore_Keymaker
import ProtonCore_Services

class FileProviderExtension: NSFileProviderExtension, LogObject {
    public static var osLog: OSLog = OSLog(subsystem: "ProtonDriveFileProvider", category: "FileProviderExtension")
    
    private lazy var itemProvider: ItemProvider = .init()
    private lazy var itemActionsOutlet: ItemActionsOutlet = .init()

    private let keymaker: Keymaker
    private let initialServices: InitialServices
    private var postLoginServices: PostLoginServices?
    
    override init() {
        PMAPIService.noTrustKit = true
        PDFileManager.configure(with: Constants.appGroup)
        
        let manager = NSFileProviderManager.default
        let keymaker = Keymaker(autolocker: nil, keychain: DriveKeychain())
        let listener = FileProviderEventsListener(manager: manager, logger: Self.self)
        let initialServices = InitialServices(clientConfig: Constants.clientApiConfig, keymaker: keymaker)
        
        self.keymaker = keymaker
        self.initialServices = initialServices
        
        super.init()
        
        self.postLoginServices = PostLoginServices(initialServices: initialServices, appGroup: Constants.appGroup, eventObservers: [listener], eventProcessingMode: .full, activityObserver: currentActivityChanged(_:))
        
        // events fetching
        self.postLoginServices?.tower.start(runEventsProcessor: true)
        
        // logout notifications can come from a) PostLoginServices b) main app when running concurrently
        DarwinNotificationCenter.shared.addObserver(self, for: .DidLogout) { [weak self] _ in
            self?.didLogout()
        }
    }
    
    deinit {
        ConsoleLogger.shared?.log("Destroy file provider", osLogType: Self.self)
        DarwinNotificationCenter.shared.removeObserver(self)
        self.postLoginServices?.tower.stop()
    }
    
    // MARK: - Session management
    
    private func currentActivityChanged(_ activity: NSUserActivity) {
        switch activity {
        case PMAPIClient.Activity.logout:
            postLoginServices?.signOut()
        default:
            break
        }
    }
    
    func didLogout() {
        ConsoleLogger.shared?.log("Some process sends DidLogout", osLogType: Self.self)
        
        self.postLoginServices?.tower.stop()
        self.postLoginServices?.resetMOCs()
        self.postLoginServices = nil
        
        self.keymaker.lockTheApp() // this will remove old main key from memory
    }
    
    /// Checks that Tower exists, MainKey is unlocked and the process has everyting for FileProvider's work
    /// Otherwise will throw to open FileProviderUI
    private func towerIfExists() throws -> Tower {
        
        if keymaker.mainKeyExists(), keymaker.mainKey == nil { // app is locked
            #if SUPPORT_BIOMETRIC_UNLOCK_IN_APPEX
            // will try to read mainKey provided by FileProviderUI extension or open FileProviderUI to initiate mainKey exchange
            let mainKey = try CrossProcessMainKeyExchange.getMainKeyOrThrowEphemeralKeypair()
            keymaker.forceInjectMainKey(mainKey)
            #else
            // will open FileProviderUI on "Not supported" screen
            throw CrossProcessErrorExchange.pinExchangeNotSupportedError
            #endif
        }
        
        if initialServices.isLoggedIn, let tower = postLoginServices?.tower { // app is logged in and appex has post login services
            return tower
        }
        
        // will open FileProviderUI on "Please Log In" screen
        throw CrossProcessErrorExchange.notAuthenticatedError
    }
    
    private func towerIfExists(_ errorHandler: (Error) -> Void) -> Tower! {
        do {
            return try towerIfExists()
        } catch {
            errorHandler(error)
            return nil
        }
    }
    
    private func towerIfExists(_ errorHandler: (NSFileProviderItem?, Error?) -> Void) -> Tower! {
        do {
            return try towerIfExists()
        } catch {
            errorHandler(nil, error)
            return nil
        }
    }
}

// MARK: - Enumeration

extension FileProviderExtension {
    override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
        let tower = try towerIfExists()
        
        do {
            switch containerItemIdentifier {
            case .workingSet:
                ConsoleLogger.shared?.log("Provide enumerator for WORKING SET", osLogType: Self.self)
                return try WorkingSetEnumerator(tower: tower)
                
            case .rootContainer:
                ConsoleLogger.shared?.log("Provide enumerator for ROOT", osLogType: Self.self)
                return try RootEnumerator(tower: tower)
                
            default:
                guard let nodeId = NodeIdentifier(containerItemIdentifier) else {
                    ConsoleLogger.shared?.log("Could not find NodeID for folder enumerator \(containerItemIdentifier)", osLogType: Self.self)
                    throw NSFileProviderError(NSFileProviderError.Code.noSuchItem)
                }
                return try FolderEnumerator(tower: tower, nodeID: nodeId)
            }
        } catch {
            throw PDFileProvider.Errors.mapToFileProviderError(error) ?? error
        }
    }
    
}

// MARK: Items metadata and contents
    
extension FileProviderExtension {
    
    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        let tower = try towerIfExists()
        
        let creatorsIfRoot = identifier == .rootContainer ? tower.sessionVault.addressIDs : []
        assert(tower.sessionVault.currentCreator() != nil, "Tried to access root without creator logged in")
        let (itemOrNil, errorOrNil) = itemProvider.item(for: identifier, creatorAddresses: creatorsIfRoot, slot: tower.fileSystemSlot!)
        
        if let error = errorOrNil {
            ConsoleLogger.shared?.log(error, osLogType: Self.self)
            throw PDFileProvider.Errors.mapToFileProviderError(error) ?? NSFileProviderError(.noSuchItem)
        }
        
        guard let item = itemOrNil else {
            ConsoleLogger.shared?.log("Failed to provide item for \(identifier)", osLogType: Self.self)
            throw NSFileProviderError(.noSuchItem)
        }

        return item
    }
    
    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        guard let item = try? self.item(for: identifier), item.contentType != .folder else {
            ConsoleLogger.shared?.log("Failed to provide url for \(identifier)", osLogType: Self.self)
            return nil
        }
        return identifier.makeUrl(filename: item.filename)
    }
    
    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        NSFileProviderItemIdentifier(url)
    }
    
    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let identifier = self.persistentIdentifierForItem(at: url), let item = try? self.item(for: identifier), !item.isFolder else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        ConsoleLogger.shared?.log("Provide placeholder for \(~item)", osLogType: Self.self)

        do {
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try FileManager.default.createDirectory(at: placeholderURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: item)
            completionHandler(nil)
        } catch let error {
            ConsoleLogger.shared?.log(error, osLogType: Self.self)
            completionHandler(error)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        guard let tower = towerIfExists(completionHandler) else { return }
        
        guard let identifier = self.persistentIdentifierForItem(at: url), let item = try? self.item(for: identifier), !item.isFolder else {
            completionHandler(NSFileProviderError(.noSuchItem))
            return
        }
        
        guard !FileManager.default.fileExists(atPath: url.path) else {
            ConsoleLogger.shared?.log("Provide file for \(~item) - already provided", osLogType: Self.self)
            completionHandler(nil)
            return
        }
        
        ConsoleLogger.shared?.log("Provide file for \(~item) - schedule download", osLogType: Self.self)
        itemProvider.fetchContents(for: identifier, slot: tower.fileSystemSlot!, downloader: tower.downloader!, storage: tower.storage) { copyUrl, item, fpError in
            if let fsError = PDFileProvider.Errors.mapToFileProviderError(fpError) {
                return completionHandler(fsError)
            }
            
            do {
                try? FileManager.default.removeItem(at: url) // opportunistic
                try FileManager.default.moveItem(at: copyUrl!, to: url) // should not fail
                completionHandler(nil)
            } catch let error {
                completionHandler(error)
            }
        }
    }
    
    override func itemChanged(at url: URL) {
        guard let identifier = self.persistentIdentifierForItem(at: url) else {
            return
        }

        do {
            let tower = try self.towerIfExists()
            let item = try self.item(for: identifier)
            ConsoleLogger.shared?.log("Item changed for \(~item)", osLogType: Self.self)
            itemActionsOutlet.modifyItem(tower: tower, item: item, baseVersion: nil, changedFields: .contents, contents: url) { modifiedItem, _, _, error in
                if let error = error {
                    ConsoleLogger.shared?.log(error, osLogType: Self.self)
                } else {
                    ConsoleLogger.shared?.log("Updated contents for \(~(modifiedItem ?? item))", osLogType: Self.self)
                }
            }
        } catch {
            ConsoleLogger.shared?.log(error, osLogType: Self.self)
        }
    }
    
    override func stopProvidingItem(at url: URL) {
        guard let identifier = self.persistentIdentifierForItem(at: url), let nodeIdentifier = NodeIdentifier(identifier) else {
            ConsoleLogger.shared?.log("Asked to stop providing unknown item, ignoring", osLogType: Self.self)
            return
        }

        do {
            ConsoleLogger.shared?.log("Stop providing item \(identifier)", osLogType: Self.self)
            let tower = try self.towerIfExists()
            tower.downloader!.cancel(operationsOf: [nodeIdentifier])
            _ = try FileManager.default.removeItem(at: url)
        } catch {
            ConsoleLogger.shared?.log(error, osLogType: Self.self)
        }
        
        self.providePlaceholder(at: url) { _ in }
    }
}

// MARK: - Actions

extension FileProviderExtension {
    
    // Create
    
    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        ConsoleLogger.shared?.log("Import document \(fileURL.lastPathComponent) under \(parentItemIdentifier)", osLogType: Self.self)
        guard let tower = towerIfExists(completionHandler) else { return }
        
        let type = MimeType(fromFileExtension: fileURL.pathExtension)
        let itemTemplate = ItemTemplate(parentId: parentItemIdentifier, filename: fileURL.lastPathComponent, type: type?.value ?? "")
        itemActionsOutlet.createItem(tower: tower, basedOn: itemTemplate, contents: fileURL) { item, _, _, error in
            let fsError = PDFileProvider.Errors.mapToFileProviderError(error)
            completionHandler(item, fsError)
        }
    }
    
    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        ConsoleLogger.shared?.log("Create directory \(directoryName) under \(parentItemIdentifier)", osLogType: Self.self)
        guard let tower = towerIfExists(completionHandler) else { return }
        
        let itemTemplate = ItemTemplate(parentId: parentItemIdentifier, filename: directoryName, type: kUTTypeFolder as String)
        itemActionsOutlet.createItem(tower: tower, basedOn: itemTemplate, contents: nil) { item, _, _, error in
            let fsError = PDFileProvider.Errors.mapToFileProviderError(error)
            completionHandler(item, fsError)
        }
    }
    
    // Modify
    
    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        ConsoleLogger.shared?.log("Rename item \(itemIdentifier) to \(itemName)", osLogType: Self.self)
        
        do {
            let tower = try towerIfExists()
            guard let item = try self.item(for: itemIdentifier) as? NodeItem else {
                throw NSFileProviderError(NSFileProviderError.Code.noSuchItem)
            }
            item.filename = itemName
            itemActionsOutlet.modifyItem(tower: tower, item: item, baseVersion: nil, changedFields: .filename, contents: nil) { item, _, _, error in
                let fsError = PDFileProvider.Errors.mapToFileProviderError(error)
                completionHandler(item, fsError)
            }
        } catch {
            completionHandler(nil, error)
        }
    }
    
    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        ConsoleLogger.shared?.log("Move item \(itemIdentifier) under \(parentItemIdentifier)", osLogType: Self.self)
        
        do {
            let tower = try towerIfExists()
            guard let item = try self.item(for: itemIdentifier) as? NodeItem else {
                throw NSFileProviderError(NSFileProviderError.Code.noSuchItem)
            }
            var changedFields = NSFileProviderItemFields.parentItemIdentifier
            item.parentItemIdentifier = parentItemIdentifier
            
            if let newName = newName {
                ConsoleLogger.shared?.log("Rename item \(itemIdentifier) to \(newName) after moving", osLogType: Self.self)
                item.filename = newName
                changedFields.insert(.filename)
            }
            
            itemActionsOutlet.modifyItem(tower: tower, item: item, baseVersion: nil, changedFields: changedFields, contents: nil) { item, _, _, error in
                let fsError = PDFileProvider.Errors.mapToFileProviderError(error)
                completionHandler(item, fsError)
            }
        } catch {
            completionHandler(nil, error)
        }
    }
    
    // Delete, Trash, Untrash
    
    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        ConsoleLogger.shared?.log("Delete item \(itemIdentifier)", osLogType: Self.self)
        guard let tower = towerIfExists(completionHandler) else { return }
        itemActionsOutlet.deleteItem(tower: tower, identifier: itemIdentifier, baseVersion: nil, completionHandler: completionHandler)
    }
    
    override func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        ConsoleLogger.shared?.log("Trash item \(itemIdentifier)", osLogType: Self.self)
        self.reparentItem(withIdentifier: itemIdentifier, toParentItemWithIdentifier: .trashContainer, newName: nil, completionHandler: completionHandler)
    }
    
    override func untrashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        ConsoleLogger.shared?.log("Untrash item \(itemIdentifier)", osLogType: Self.self)
        
        // untrash, "toParentItemWithIdentifier" just needs to be different from .trashContainer
        self.reparentItem(withIdentifier: itemIdentifier, toParentItemWithIdentifier: .workingSet, newName: nil) { item, error in
            switch (item, parentItemIdentifier, error) {
            case let (.some(updatedItem), .some(newParent), .none):
                // move to new parent if needed
                ConsoleLogger.shared?.log("Move item \(itemIdentifier) to \(newParent) after untrashing", osLogType: Self.self)
                self.reparentItem(withIdentifier: updatedItem.itemIdentifier, toParentItemWithIdentifier: newParent, newName: nil, completionHandler: completionHandler)
            default:
                completionHandler(item, error)
            }
        }
    }
}
