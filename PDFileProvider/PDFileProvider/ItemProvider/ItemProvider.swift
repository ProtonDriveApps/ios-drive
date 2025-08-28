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
import FileProvider
import PDClient
import PDCore
import CoreData
import ProtonCoreNetworking

public final class ItemProvider {
    private let decryptor = RevisionDecryptor()
    
    public init() { }
    
    /// Triggers fetching an item's metadata and returns a Progress object.
    @discardableResult
    public func itemProgress(
        for identifier: NSFileProviderItemIdentifier,
        creatorAddresses: Set<String>,
        fileSystemSlot: FileSystemSlot,
        cloudSlot: any CloudSlotProtocol,
        completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void
    ) -> Progress
    {
        let task = Task { [weak self] in
            guard !Task.isCancelled else { return }
            guard let (item, error) = await self?.localOrRemoteItem(
                for: identifier,
                creatorAddresses: creatorAddresses,
                fileSystemSlot: fileSystemSlot,
                cloudSlot: cloudSlot
            )
            else { return }
            guard !Task.isCancelled else { return }
            completionHandler(item, error)
        }
        return Progress { _ in
            Log.info("Item for identifier cancelled", domain: .fileProvider)
            task.cancel()
            completionHandler(nil, CocoaError(.userCancelled))
        }
    }
    
    /// Synchronously returns a local item (or error, if item was not found locally).
    /// Creator is relevant only for root folder.
    public func localItem(
        for identifier: NSFileProviderItemIdentifier,
        creatorAddresses: Set<String>,
        fileSystemSlot: FileSystemSlot
    ) -> (NSFileProviderItem?, Error?) {
        switch identifier {
        case .rootContainer:
            guard !creatorAddresses.isEmpty, let mainShare = fileSystemSlot.getMainShare(of: creatorAddresses), let root = fileSystemSlot.moc.performAndWait({ mainShare.root }) else {
                Log.error(error: Errors.noMainShare, domain: .fileProvider)
                return (nil, Errors.noMainShare)
            }
            Log.info("Got item ROOT", domain: .fileProvider)
            do {
                let item = try NodeItem(node: root)
                return (item, nil)
            } catch {
                return (nil, Errors.itemCannotBeCreated)
            }

        case .workingSet:
            Log.info("Getting item WORKING_SET does not make sense", domain: .fileProvider)
            return (nil, Errors.requestedItemForWorkingSet)
            
        case .trashContainer:
            Log.info("Getting item TRASH does not make sense", domain: .fileProvider)
            return (nil, Errors.requestedItemForTrash)

        default:
            guard let nodeId = NodeIdentifier(identifier) else {
                Log.error(error: Errors.nodeIdentifierNotFound, domain: .fileProvider)
                return (nil, Errors.nodeIdentifierNotFound)
            }
            guard let node = fileSystemSlot.getNode(nodeId) else {
                Log.error(error: Errors.nodeNotFound, domain: .fileProvider)
                return (nil, Errors.nodeNotFound)
            }
            guard node.state != .deleted && !node.isTrashInheriting else {
                // We don't want trashed items to display locally (disassociated items are
                // no longer managed by the File Provider and so don't get asked for)
                return (nil, Errors.nodeNotFound)
            }

            do {
                let item = try NodeItem(node: node)
                Log.debug("Got item \(~item)", domain: .fileProvider)
                return (item, nil)
            } catch {
                return (nil, Errors.itemCannotBeCreated)
            }
        }
    }

    /// Returns a local item if available, otherwise fetches it remotely.
    /// If neither is found, returns an error.
    /// Creator is relevant only for root folder.
    private func localOrRemoteItem(
        for identifier: NSFileProviderItemIdentifier,
        creatorAddresses: Set<String>,
        fileSystemSlot: FileSystemSlot,
        cloudSlot: any CloudSlotProtocol
    ) async -> (NSFileProviderItem?, Error?) {
        // Try locally...
        let (localItem, error) = localItem(for: identifier, creatorAddresses: creatorAddresses, fileSystemSlot: fileSystemSlot)

        // Ignore lookups for the working set and trash (which we don't support)
        if case Errors.requestedItemForWorkingSet? = error {
            return (nil, error)
        }
        if case Errors.requestedItemForTrash? = error {
            return (nil, error)
        }

        // ...if item was found, don't try remote — we have metadata...
        guard localItem == nil else {
            return (localItem, error)
        }

        // ...if that doesn't work, try remotely.
        guard let nodeId = NodeIdentifier(identifier) else {
            Log.error("localOrRemoteItem - nodeIdentifierNotFound", error: Errors.nodeIdentifierNotFound, domain: .fileProvider, context: LogContext("Identifier: \(identifier)"))
            return (nil, Errors.nodeIdentifierNotFound)
        }

        do {
            let remoteNode = try await cloudSlot.scanNode(nodeId, linkProcessingErrorTransformer: { $1 })
            
            guard remoteNode.state != .deleted, !remoteNode.isTrashInheriting else {
                // We don't want trashed items to display locally (disassociated items are
                // no longer managed by the File Provider and so don't get asked for)
                return (nil, Errors.nodeNotFound)
            }
            do {
                let item = try NodeItem(node: remoteNode)
                Log.debug("Got item \(~item)", domain: .fileProvider)
                return (item, nil)
            } catch {
                return (nil, Errors.itemCannotBeCreated)
            }
        } catch {
            if let responseError = error as? ResponseError,
               responseError.responseCode == APIErrorCodes.itemOrItsParentDeletedErrorCode.rawValue {
                return (nil, Errors.nodeNotFound)
            } else {
                return (nil, error)
            }
        }
    }

    /// Fetches contents, checking whether a node exists remotely if it doesn't exist locally, and asynchronously returns a Progress object.
    // swiftlint:disable:next function_parameter_count
    @discardableResult
    public func fetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion? = nil,
        nodeFetcher: (NSFileProviderItemIdentifier) async -> Node?,
        downloader: Downloader,
        storage: StorageManager,
        useRefreshableDownloadOperation: Bool,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) async -> Progress
    {
        Log.info("Start fetching contents for \(itemIdentifier)", domain: .fileProvider)

        let moc = storage.newBackgroundContext()
        guard let file = await nodeFetcher(itemIdentifier) as? File
        else {
            Log.error(error: Errors.nodeNotFound, domain: .fileProvider)
            completionHandler(nil, nil, Errors.nodeNotFound)
            return Progress { _ in
                Log.info("Fetch contents for \(itemIdentifier) cancelled", domain: .fileProvider)
                completionHandler(nil, nil, CocoaError(.userCancelled))
            }
        }

        return getProgress(
            for: file,
            moc: moc,
            downloader: downloader,
            useRefreshableDownloadOperation: useRefreshableDownloadOperation,
            completionHandler: completionHandler)
    }

    /// Fetches contents without checking whether a node exists remotely if it doesn't exist locally, and synchronously returns a Progress object.
    // swiftlint:disable:next function_parameter_count
    @discardableResult
    public func legacyFetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion? = nil,
        fileSystemSlot: FileSystemSlot,
        downloader: Downloader,
        storage: StorageManager,
        useRefreshableDownloadOperation: Bool,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress
    {
        Log.info("Start fetching contents for \(itemIdentifier)", domain: .fileProvider)

        let moc = storage.newBackgroundContext()
        guard let fileId = NodeIdentifier(itemIdentifier) else {
            Log.error(error: Errors.nodeIdentifierNotFound, domain: .fileProvider)
            completionHandler(nil, nil, Errors.nodeIdentifierNotFound)
            return Progress { _ in
                Log.info("Fetch contents for \(itemIdentifier) cancelled", domain: .fileProvider)
                completionHandler(nil, nil, CocoaError(.userCancelled))
            }
        }
        guard let file = fileSystemSlot.getNode(fileId, moc: moc) as? File else {
            Log.error(error: Errors.nodeNotFound, domain: .fileProvider)
            completionHandler(nil, nil, Errors.nodeNotFound)
            return Progress { _ in
                Log.info("Fetch contents for \(itemIdentifier) cancelled", domain: .fileProvider)
                completionHandler(nil, nil, CocoaError(.userCancelled))
            }
        }

        return getProgress(
            for: file,
            moc: moc,
            downloader: downloader,
            useRefreshableDownloadOperation: useRefreshableDownloadOperation,
            completionHandler: completionHandler)
    }

    private func getProgress(
        for file: File,
        moc: NSManagedObjectContext,
        downloader: Downloader,
        useRefreshableDownloadOperation: Bool,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) -> Progress {
        Log.info("- identifier \(file.identifier) stands for \(~file)", domain: .fileProvider)

        // check if cyphertext of active revision is already available locally
        if let revision = cachedRevision(for: file, on: moc) {
            let task = Task { [weak self] in
                do {
                    guard !Task.isCancelled else { return }
                    guard let clearUrl = try await self?.decryptor.decrypt(revision, on: moc) else { return }
                    Log.info("Found cached cypherdata for \(~file), prepared cleartext at temp location", domain: .fileProvider)
                    do {
                        let item = try NodeItem(node: file)
                        completionHandler(clearUrl, item, nil)
                    } catch {
                        completionHandler(nil, nil, error)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    // if can not decrypted, proceed to download
                    self?.downloadAndDecrypt(
                        file,
                        downloader: downloader,
                        moc: moc,
                        useRefreshableDownloadOperation: useRefreshableDownloadOperation,
                        completionHandler: completionHandler
                    )
                }
            }
            return Progress { _ in
                Log.info("Fetch contents for \(file.identifier) cancelled", domain: .fileProvider)
                task.cancel()
                completionHandler(nil, nil, CocoaError(.userCancelled))
            }
        } else {
            // if not cached, proceed to download
            return downloadAndDecrypt(
                file,
                downloader: downloader,
                moc: moc,
                useRefreshableDownloadOperation: useRefreshableDownloadOperation,
                completionHandler: completionHandler
            )
        }
    }

    @discardableResult
    private func downloadAndDecrypt(
        _ file: File,
        downloader: Downloader,
        moc: NSManagedObjectContext,
        useRefreshableDownloadOperation: Bool,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
            Log.info("Schedule download operation for \(~file)", domain: .fileProvider)
            let operation = downloader.scheduleDownloadFileProvider(
                cypherdataFor: file,
                useRefreshableDownloadOperation: useRefreshableDownloadOperation
            ) { [unowned self] result in
                switch result {
                case let .success(fileInOtherMoc):
                    let file = fileInOtherMoc.in(moc: moc)

                    guard let revision = cachedRevision(for: file, on: moc) else {
                        Log.error(error: Errors.revisionNotFound, domain: .fileProvider)
                        completionHandler(nil, nil, Errors.revisionNotFound)
                        return
                    }

                    Task { [weak self] in
                        do {
                            guard let url = try await self?.decryptor.decrypt(revision, on: moc) else { return }

                            Log.info("Prepared cleartext content of \(~file) at temp location", domain: .fileProvider)
                            let item = try NodeItem(node: file)

                            moc.performAndWait {
#if os(macOS)
                                file.activeRevision?.removeOldBlocks(in: moc)
                                try? moc.saveOrRollback()
#else
                                moc.reset()
#endif
                            }
                            completionHandler(url, item, nil)
                        } catch {
                            Log.error(error: error, domain: .fileProvider)
                            completionHandler(nil, nil, error)
                        }
                    }

                case let .failure(error):
                    Log.error(error: error, domain: .fileProvider)
                    completionHandler(nil, nil, error)
                }
            }

            return (operation as? OperationWithProgress).map {
                $0.progress.setOneTimeCancellationHandler { [weak operation] _ in
                    Log.info("Download and decrypt operation cancelled", domain: .fileProvider)
                    operation?.cancel()
                    completionHandler(nil, nil, CocoaError(.userCancelled))
                }
            } ?? Progress { [weak operation] _ in
                Log.info("Download and decrypt operation cancelled", domain: .fileProvider)
                operation?.cancel()
                completionHandler(nil, nil, CocoaError(.userCancelled))
            }
        }
    
    private func cachedRevision(for file: File, on moc: NSManagedObjectContext) -> PDCore.Revision? {
        return moc.performAndWait {
            if let revision = file.activeRevision, revision.blocksAreValid() {
                return revision
            } else {
                return nil
            }
        }
    }
}
