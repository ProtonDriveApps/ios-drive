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
import PDClient
import CoreServices
import ProtonCoreLog
import ProtonCoreAuthentication
import ProtonCoreKeymaker
import ProtonCoreServices
import ProtonCoreCryptoGoInterface
import ProtonCoreCryptoPatchedGoImplementation
import PDUploadVerifier
import PDSDKCore
import PDSDKCoreiOS

class FileProviderExtension: NSFileProviderExtension {
    @SettingsStorage("firstLaunchHappened") private var firstLaunchHappened: Bool?
    private let itemProvider: ItemProviderForiOS
    private let itemActionsOutlet: ItemActionsOutlet
    private let keymaker: Keymaker
    private let bootstrapQueue = DispatchQueue(label: "ch.protonmail.drive.FileProviderExtension")

    private var initialServices: InitialServices?
    private var postLoginServices: PostLoginServices?
    private let logConfigurator: LogsConfigurator
    private var memoryResource: FileProviderMemoryMonitoringResource?

    override init() {
        self._firstLaunchHappened.configure(with: Constants.appGroup)
        inject(cryptoImplementation: ProtonCoreCryptoPatchedGoImplementation.CryptoGoMethodsImplementation.instance)
        PDFileManager.configure(with: Constants.appGroup)
        // Inject build type to enable build differentiation. (Build macros don't work in SPM)
        PDCore.Constants.buildType = Constants.buildType

        self.keymaker = DriveKeymaker(autolocker: nil, keychain: DriveKeychain.shared)
        self.itemProvider = ItemProviderForiOS()
        self.itemActionsOutlet = ItemActionsOutlet(
            fileProviderManager: NSFileProviderManager.default,
            newRevisionUploadPerformProvider: {
                NewRevisionUploadPerformerForiOS()
            }
        )
        let defaultHost = Constants.clientApiConfig.environment.doh.defaultHost
        self.logConfigurator = LogsConfigurator(logSystem: .iOSFileProvider, localSettings: LocalSettings.shared, defaultHost: defaultHost)

        super.init()

        // logout notifications can come from a) PostLoginServices b) main app when running concurrently
        DarwinNotificationCenter.shared.addObserver(self, for: .DidLogout) { [weak self] _ in
            self?.didLogout()
        }
        self.memoryResource = FileProviderMemoryMonitoringResource(resource: DeviceMemoryDiagnosticsResource())
    }

    private func bootstrapExtensionIfNeeded() {
        // multiple handlers of FileProviderExtension can be called concurrently
        // but the bootstrap should happen only once
        bootstrapQueue.sync {
            guard initialServices == nil, postLoginServices == nil else { return }

            // This initializer immediately calls networkService.acquireSessionIfNeeded, and
            // it also runs detached Task to fetch Unleash flags using networkService.
            // Both require access token and would produce unauthenticated one if no auth token is available.
            // That will cause creation of unauthenticated token which we do not need in FP extension.
            self.initialServices = InitialServices(
                userDefault: Constants.appGroup.userDefaults,
                clientConfig: Constants.clientApiConfig,
                mainKeyProvider: keymaker,
                autoLocker: nil,
                sessionRelatedCommunicatorFactory: { sessionStore, authenticator, onSessionReceived in
                    SessionRelatedCommunicatorForExtension(
                        userDefaultsConfiguration: .forFileProviderExtension(userDefaults: Constants.appGroup.userDefaults),
                        sessionStorage: sessionStore,
                        childSessionKind: .fileProviderExtension,
                        onChildSessionObtained: onSessionReceived
                    )
                }
            )

            let listener = FileProviderEventsListener(manager: NSFileProviderManager.default)
            let uploadVerifierFactory = ConcreteUploadVerifierFactory()
            self.postLoginServices = PostLoginServices(
                initialServices: initialServices!,
                appGroup: Constants.appGroup,
                eventObservers: [listener],
                eventProcessingMode: .full,
                eventLoopInterval: 90,
                uploadVerifierFactory: uploadVerifierFactory,
                activityObserver: { [weak self] activity in
                    self?.currentActivityChanged(activity)
                }
            )
            self.postLoginServices?.tower.start(options: .runEventsProcessor)
            guard let tower = postLoginServices?.tower else {
                return
            }

            let discoverer = RecursiveValidNameDiscoverer(hashChecker: tower.cloudSlot)
            itemActionsOutlet.set(validNameDiscoverer: discoverer)

            let semaphore = DispatchSemaphore(value: 0)
            Task {
                try await self.bootstrapSDK(tower: tower)
                semaphore.signal()
            }
            semaphore.wait()
            let downloaders: [DownloaderProtocol?] = [tower.downloader, tower.getSdkFileDownloader()]
            let treeTrashHandler = NodeTreeTrashHandler(downloaders: downloaders.compactMap { $0 })
            let treeOperator = NodeTreeOperator(dependencies: .init(trashHandler: treeTrashHandler))
            tower.set(nodeTreeOperator: treeOperator)
            tower.set(treeTrashHandler: treeTrashHandler)
        }
    }

    private func bootstrapSDK(tower: Tower) async throws {
        guard let performer = try await initializeSDKOperationPerformer(tower: tower) else {
            return
        }
        await MainActor.run {
            let uploaderFactory = SDKFileUploaderFactory(
                encoder: JSONEncoder(),
                managedObjectContext: tower.storage.backgroundContext,
                protectionResource: keymaker,
                thumbnailProvider: ThumbnailProviderFactory.defaultSynchronizedThumbnailProvider
            )
            let uploader = uploaderFactory
                .makeFileUploader(
                    bytesCounterResource: ThreadSafeBytesCounterResource(),
                    operationPerformer: performer
                )
            tower.set(sdkFileUploader: uploader)
            
            let downloader = SDKDownloaderFactory().makeFileDownloader(
                operationPerformer: performer,
                managedObjectContext: tower.storage.backgroundContext
            )
            tower.set(sdkFileDownloader: downloader)
        }
        let revisionUploader = SDKRevisionUploaderFactory().makeUploader(
            operationPerformer: performer,
            managedObjectContext: tower.storage.backgroundContext
        )
        tower.set(sdkRevisionUploader: revisionUploader)
    }

    private func initializeSDKOperationPerformer(
        tower: Tower
    ) async throws -> FileOperationPerformer? {
        guard tower.localSettings.driveiOSSDKDownloadMain || tower.localSettings.driveiOSSDKUploadMain else {
            return nil
        }
        return try await SDKOperationPerformerFactory().makeFilePerformer(tower: tower)
    }

    deinit {
        Log.info("Destroy file provider", domain: .fileProvider)
        DarwinNotificationCenter.shared.removeObserver(self)
        self.postLoginServices?.tower.stop()
    }

    // MARK: - Session management

    private func currentActivityChanged(_ activity: NSUserActivity) {
        switch activity {
        case PMAPIClient.Activity.logout:
            postLoginServices?.signOut()
        case PMAPIClient.Activity.childSessionExpired:
            // first, stop all ongoing activities
            self.postLoginServices?.tower.stop()

            // this invokes `towerIfExists()` that properly throws causing FileProviderUI to show up
            NSFileProviderManager.default.signalEnumerator(for: .rootContainer, completionHandler: { _ in })
            NSFileProviderManager.default.signalEnumerator(for: .workingSet, completionHandler: { _ in })
        default:
            break
        }
    }

    func didLogout() {
        Log.info("Some process sends DidLogout", domain: .fileProvider)

        self.postLoginServices?.tower.stop()
        self.postLoginServices?.resetMOCs()
        self.postLoginServices = nil

        self.initialServices = nil

        self.keymaker.lockTheApp() // this will remove old main key from memory
    }

    /// Checks that Tower exists, MainKey is unlocked and the process has everyting for FileProvider's work
    /// Otherwise will throw to open FileProviderUI
    private func towerIfExists() throws -> Tower {

        // Intentionally using keymaker like this.
        // otherwise, the if block executes even though the condition is false.
        let keyExists = keymaker.mainKeyExists()
        let mainKey = try keymaker.mainKeyOrError
        if keyExists && mainKey == nil { // app is locked
            #if SUPPORT_BIOMETRIC_UNLOCK_IN_APPEX
            // will try to read mainKey provided by FileProviderUI extension or open FileProviderUI to initiate mainKey exchange
            let mainKey = try CrossProcessMainKeyExchange.getMainKeyOrThrowEphemeralKeypair()
            keymaker.forceInjectMainKey(mainKey)
            #else
            // will open FileProviderUI on "Not supported" screen
            throw CrossProcessErrorExchange.pinExchangeNotSupportedError
            #endif
        }

        bootstrapExtensionIfNeeded()

        guard let initialServices else {
            fatalError("Tried to operate before bootstrapping the extension")
        }

        if initialServices.sessionRelatedCommunicator.isChildSessionExpired() {
            throw CrossProcessErrorExchange.childSessionExpiredError
        }

        guard
            firstLaunchHappened == true,
            let tower = postLoginServices?.tower,
            initialServices.isLoggedIn
        else {
            // will open FileProviderUI on "Please Log In" screen
            throw CrossProcessErrorExchange.notAuthenticatedError
        }
        if let userID = tower.sessionVault.userInfo?.ID {
            PDFileManager.set(userID: userID)
        }
        return tower
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
        let moc = tower.storage.backgroundContext
        let keepDownloadedManager = KeepDownloadedEnumerationManager(fileSystemSlot: tower.fileSystemSlot, fileProviderManager: NSFileProviderManager.default)

        do {
            switch containerItemIdentifier {
            case .workingSet:
                Log.info("Provide enumerator for WORKING SET", domain: .enumerating)
                return WorkingSetEnumerator(tower: tower, keepDownloadedManager: keepDownloadedManager)

            case .rootContainer:
                guard let rootID = tower.rootFolderIdentifier(moc: moc) else {
                    Log.info("Enumerator for ROOT cannot be provided because there is no rootID", domain: .enumerating)
                    throw Errors.rootNotFound
                }
                Log.info("Provide enumerator for ROOT", domain: .enumerating)
                return RootEnumerator(tower: tower,
                                      keepDownloadedManager: keepDownloadedManager,
                                      rootID: rootID)

            default:
                guard let nodeId = NodeIdentifier(containerItemIdentifier) else {
                    Log.error("Could not find NodeID for folder enumerator \(containerItemIdentifier)", error: nil, domain: .enumerating)
                    throw NSFileProviderError(NSFileProviderError.Code.noSuchItem)
                }
                let isFolder = moc.performAndWait {
                    let node = tower.fileSystemSlot?.getNode(nodeId, moc: moc)
                    return node?.isFolder ?? false
                }
                if !isFolder {
                    // Empty enumerator. Since iOS 26 even files can be enumerated, but we only allow 1 active revision.
                    return FileEnumerator()
                } else {
                    return FolderEnumerator(
                        tower: tower,
                        keepDownloadedManager: keepDownloadedManager,
                        nodeID: nodeId
                    )
                }
            }
        } catch {
            throw PDFileProvider.Errors.mapLegacyErrorToFileProviderError(error)
        }
    }

}

// MARK: Items metadata and contents

extension FileProviderExtension {

    override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
        let tower = try towerIfExists()

        let creatorsIfRoot = identifier == .rootContainer ? tower.sessionVault.addressIDs : []
        assert(tower.sessionVault.currentCreator() != nil, "Tried to access root without creator logged in")
        let itemOrError = itemProvider.localItem(for: identifier, creatorAddresses: creatorsIfRoot, fileSystemSlot: tower.fileSystemSlot!, moc: tower.storage.backgroundContext)

        switch itemOrError {
        case .success(let item):
            return item
        case .failure(let error):
            Log.error(error: error, domain: .fileProvider)
            throw PDFileProvider.Errors.mapLegacyErrorToFileProviderError(error)
        }
    }

    override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
        guard let item = try? self.item(for: identifier) else {
            Log.error("Failed to provide url for \(identifier)", error: nil, domain: .fileProvider)
            return nil
        }
        return identifier.makeUrl(item: item)
    }

    override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
        NSFileProviderItemIdentifier(url)
    }

    override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let identifier = self.persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem)) // no identifier means no way to pass identifier in error
            return
        }
        guard let item = try? self.item(for: identifier), !item.isFolder else {
            completionHandler(NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier))
            return
        }
        Log.info("Provide placeholder for \(~item)", domain: .fileProvider)

        do {
            let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
            try FileManager.default.createDirectory(at: placeholderURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try NSFileProviderManager.writePlaceholder(at: placeholderURL, withMetadata: item)
            completionHandler(nil)
        } catch let error {
            Log.error(error: error, domain: .fileProvider)
            completionHandler(error)
        }
    }

    override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
        guard let tower = towerIfExists(completionHandler) else { return }

        guard let identifier = self.persistentIdentifierForItem(at: url) else {
            completionHandler(NSFileProviderError(.noSuchItem)) // no identifier means no way to pass identifier in error
            return
        }
        guard let item = try? self.item(for: identifier), !item.isFolder else {
            completionHandler(NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier))
            return
        }

        guard !FileManager.default.fileExists(atPath: url.path) else {
            Log.warning("Provide file for \(~item) - already provided", domain: .fileProvider)
            completionHandler(nil)
            return
        }

        Task {
            guard !isCloudBasedFile(item) else {
                // Since iOS 26 `startProvidingItem` is called also for files with no revision (proton cloud files)
                // We need to prepare a mock empty file in disk otherwise the OS doesn't recognize the extension
                // (without it the OS tries to invoke QuickLook instead of transferring to main app)
                Log.info("Provide empty file for proton file: \(~item)", domain: .fileProvider)
                prepareEmptyDataPlaceholder(url)
                completionHandler(nil)
                return
            }

            Log.info("Provide file for \(~item) - schedule download", domain: .fileProvider)
            await itemProvider.fetchContents(
                for: identifier,
                nodeFetcher: { await tower.node(itemIdentifier: $0, in: $1) },
                downloader: tower.downloader!,
                storage: tower.storage,
                tower: tower,
                completionHandler: { copyUrl, item, fpError in
                    if let fsError = PDFileProvider.Errors.mapLegacyErrorToFileProviderErrorIfPossible(fpError) {
                        return completionHandler(fsError)
                    }

                    do {
                        try? FileManager.default.removeItem(at: url) // opportunistic
                        // Check `CoreDataFilePreviewRepository.loadFile()` for more details 
                        try FileManager.default.linkItem(at: copyUrl!, to: url)
                        completionHandler(nil)
                    } catch let error {
                        completionHandler(error)
                    }
                }
            )
        }
    }

    private func prepareEmptyDataPlaceholder(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? Data().write(to: url)
    }

    private func isCloudBasedFile(_ item: NSFileProviderItem) -> Bool {
        guard let contentType = item.contentType else {
            return false
        }

        let uti = UTI(value: contentType.identifier)
        return uti.isProtonFile
    }

    override func itemChanged(at url: URL) {
        guard let identifier = self.persistentIdentifierForItem(at: url) else {
            return
        }

        do {
            let tower = try self.towerIfExists()
            let item = try self.item(for: identifier)
            Log.info("Item changed for \(~item)", domain: .fileProvider)
            itemActionsOutlet.modifyItem(tower: tower, item: item, baseVersion: nil, changedFields: .contents, contents: url, pool: tower.storage.backgroundContextPool) { modifiedItem, _, _, error in
                if let error = error {
                    Log.error(error: error, domain: .fileProvider)
                } else {
                    Log.info("Updated contents for \(~(modifiedItem ?? item))", domain: .fileProvider)
                }
            }
        } catch {
            Log.error(error: error, domain: .fileProvider)
        }
    }

    override func stopProvidingItem(at url: URL) {
        guard let identifier = self.persistentIdentifierForItem(at: url), let nodeIdentifier = NodeIdentifier(identifier) else {
            Log.info("Asked to stop providing unknown item, ignoring", domain: .fileProvider)
            return
        }

        do {
            Log.info("Stop providing item \(identifier)", domain: .fileProvider)
            let tower = try self.towerIfExists()
            itemProvider.cancelDownload(identifier: nodeIdentifier, tower: tower)
            _ = try FileManager.default.removeItem(at: url)
        } catch {
            Log.error(error: error, domain: .fileProvider)
        }

        self.providePlaceholder(at: url) { _ in }
    }
}

// MARK: - Actions

extension FileProviderExtension {

    // Create

    override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Log.info("Import document \(fileURL.lastPathComponent) under \(parentItemIdentifier)", domain: .fileProvider)
        guard let tower = towerIfExists(completionHandler) else { return }

        let type = MimeType(fromFileExtension: fileURL.pathExtension)
        let itemTemplate = ItemTemplate(parentId: parentItemIdentifier, filename: fileURL.lastPathComponent, type: type?.value ?? "")
        itemActionsOutlet.createItem(tower: tower, basedOn: itemTemplate, contents: fileURL, pool: tower.storage.backgroundContextPool) { item, _, _, error in
            let fsError = PDFileProvider.Errors.mapLegacyErrorToFileProviderErrorIfPossible(error)
            completionHandler(item, fsError)
        }
    }

    override func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Log.info("Create directory \(directoryName) under \(parentItemIdentifier)", domain: .fileProvider)
        guard let tower = towerIfExists(completionHandler) else { return }

        let itemTemplate = ItemTemplate(parentId: parentItemIdentifier, filename: directoryName, type: kUTTypeFolder as String)
        itemActionsOutlet.createItem(tower: tower, basedOn: itemTemplate, contents: nil, pool: tower.storage.backgroundContextPool) { item, _, _, error in
            let fsError = PDFileProvider.Errors.mapLegacyErrorToFileProviderErrorIfPossible(error)
            completionHandler(item, fsError)
        }
    }

    // Modify

    override func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Log.info("Rename item \(itemIdentifier) to \(itemName)", domain: .fileProvider)

        do {
            let tower = try towerIfExists()
            guard let item = try self.item(for: itemIdentifier) as? NodeItem else {
                throw NSFileProviderError(NSFileProviderError.Code.noSuchItem)
            }
            item.filename = itemName
            itemActionsOutlet.modifyItem(tower: tower, item: item, baseVersion: nil, changedFields: .filename, contents: nil, pool: tower.storage.backgroundContextPool) { item, _, _, error in
                let fsError = PDFileProvider.Errors.mapLegacyErrorToFileProviderErrorIfPossible(error)
                completionHandler(item, fsError)
            }
        } catch {
            completionHandler(nil, error)
        }
    }

    override func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Log.info("Move item \(itemIdentifier) under \(parentItemIdentifier)", domain: .fileProvider)

        do {
            let tower = try towerIfExists()
            guard let item = try self.item(for: itemIdentifier) as? NodeItem else {
                throw NSFileProviderError(NSFileProviderError.Code.noSuchItem)
            }
            var changedFields: PDFileProvider.NSFileProviderItemFields = NSFileProviderItemFields.parentItemIdentifier
            item.parentItemIdentifier = parentItemIdentifier

            if let newName = newName {
                Log.info("Rename item \(itemIdentifier) to \(newName) after moving", domain: .fileProvider)
                item.filename = newName
                changedFields.insert(.filename)
            }

            itemActionsOutlet.modifyItem(tower: tower, item: item, baseVersion: nil, changedFields: changedFields, contents: nil, pool: tower.storage.backgroundContextPool) { item, _, _, error in
                let fsError = PDFileProvider.Errors.mapLegacyErrorToFileProviderErrorIfPossible(error)
                completionHandler(item, fsError)
            }
        } catch {
            completionHandler(nil, error)
        }
    }

    // Delete, Trash, Untrash

    override func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        Log.info("Delete item \(itemIdentifier)", domain: .fileProvider)
        guard let tower = towerIfExists(completionHandler) else { return }
        itemActionsOutlet.deleteItem(tower: tower, identifier: itemIdentifier, baseVersion: nil, pool: tower.storage.backgroundContextPool, completionHandler: completionHandler)
    }

    override func trashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Log.info("Trash item \(itemIdentifier)", domain: .fileProvider)
        self.reparentItem(
            withIdentifier: itemIdentifier,
            toParentItemWithIdentifier: .trashContainer,
            newName: nil,
            completionHandler: completionHandler
        )
    }

    override func untrashItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        Log.info("Untrash item \(itemIdentifier)", domain: .fileProvider)

        // untrash, "toParentItemWithIdentifier" just needs to be different from .trashContainer
        self.reparentItem(withIdentifier: itemIdentifier, toParentItemWithIdentifier: .workingSet, newName: nil) { item, error in
            switch (item, parentItemIdentifier, error) {
            case let (.some(updatedItem), .some(newParent), .none):
                // move to new parent if needed
                Log.info("Move item \(itemIdentifier) to \(newParent) after untrashing", domain: .fileProvider)
                self.reparentItem(withIdentifier: updatedItem.itemIdentifier, toParentItemWithIdentifier: newParent, newName: nil, completionHandler: completionHandler)
            default:
                completionHandler(item, error)
            }
        }
    }
}
