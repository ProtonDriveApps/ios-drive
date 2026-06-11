// Copyright (c) 2025 Proton AG
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

#if os(iOS)

import Foundation
import FileProvider
import PDClient
import PDCore
import CoreData
import ProtonCoreNetworking

public final class ItemProviderForiOS {
    private let decryptor = RevisionDecryptor()

    public init() {}

    public func fetchContents(
        for itemIdentifier: NSFileProviderItemIdentifier,
        version requestedVersion: NSFileProviderItemVersion? = nil,
        nodeFetcher: (NSFileProviderItemIdentifier, NSManagedObjectContext) async -> Node?,
        downloader: Downloader,
        storage: StorageManager,
        tower: Tower,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) async
    {
        Log.info("Start fetching contents for \(itemIdentifier)", domain: .fileProvider)

        let moc = storage.newBackgroundContext()
        guard let file = await nodeFetcher(itemIdentifier, moc) as? File else {
            Log.error(error: Errors.nodeNotFound(identifier: itemIdentifier), domain: .fileProvider)
            completionHandler(nil, nil, Errors.nodeNotFound(identifier: itemIdentifier))
            return
        }

        return getClearTextURL(
            for: file,
            moc: moc,
            downloader: downloader,
            tower: tower,
            completionHandler: completionHandler
        )
    }

    public func cancelDownload(identifier: NodeIdentifier, tower: Tower) {
        tower.downloader?.cancel(operationsOf: [identifier])
        tower.getSdkFileDownloader()?.cancel(operationsOf: [identifier.any()])
    }

    private func getClearTextURL(
        for file: File,
        moc: NSManagedObjectContext,
        downloader: Downloader,
        tower: Tower,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) {
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
                    self?.download(
                        file,
                        downloader: downloader,
                        tower: tower,
                        moc: moc,
                        completionHandler: completionHandler
                    )
                }
            }
        } else {
            // if not cached, proceed to download
            download(
                file,
                downloader: downloader,
                tower: tower,
                moc: moc,
                completionHandler: completionHandler
            )
        }
    }

    private func download(
        _ file: File,
        downloader: Downloader,
        tower: Tower,
        moc: NSManagedObjectContext,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) {
        if let sdkDownloader = tower.getSdkFileDownloader() {
            downloadViaSDK(file, sdkDownloader: sdkDownloader, moc: moc, completionHandler: completionHandler)
        } else {
            downloadViaLegacy(file, downloader: downloader, moc: moc, completionHandler: completionHandler)
        }
    }

    private func downloadViaSDK(
        _ file: File,
        sdkDownloader: SDKFileDownloaderProtocol,
        moc: NSManagedObjectContext,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) {
        Log.info("Start download for \(~file) via SDK", domain: .fileProvider)

        Task {
            do {
                try await sdkDownloader.download(file: file.identifier.any())
                let item = try NodeItem(node: file)
                guard let revision = file.activeRevision else {
                    let error = Errors.revisionNotFound
                    Log.error("Failed to get active revision", error: error, domain: .fileProvider)
                    completionHandler(nil, nil, error)
                    return
                }
                guard let url = revision.validatedDecryptedFilePath() else {
                    let error = Errors.itemCannotBeCreated
                    Log.error("Failed to get decrypted file path", error: nil, domain: .fileProvider)
                    completionHandler(nil, nil, error)
                    return
                }
                completionHandler(url, item, nil)
            } catch {
                Log.error(error: error, domain: .fileProvider)
                completionHandler(nil, nil, error)
            }
        }
    }

    private func downloadViaLegacy(
        _ file: File,
        downloader: Downloader,
        moc: NSManagedObjectContext,
        completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) {
            Log.info("Schedule download operation for \(~file) via legacy", domain: .fileProvider)
            let operation = downloader.scheduleDownloadFileProvider(
                cypherdataFor: file,
                useRefreshableDownloadOperation: true
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
                                moc.reset()
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
    }

    private func cachedRevision(for file: File, on moc: NSManagedObjectContext) -> PDCore.Revision? {
        return moc.performAndWait {
            guard let revision = file.activeRevision else {
                return nil
            }
            return revision.isAvailableLocally() ? revision : nil
        }
    }

    /// Synchronously returns a local item (or error, if item was not found locally).
    /// Creator is relevant only for root folder.
    public func localItem(
        for identifier: NSFileProviderItemIdentifier,
        creatorAddresses: Set<String>,
        fileSystemSlot: FileSystemSlot,
        moc: NSManagedObjectContext
    ) -> Result<NSFileProviderItem, Errors> {
        switch identifier {
        case .rootContainer:
            guard !creatorAddresses.isEmpty, let mainShare = fileSystemSlot.getMainShare(of: creatorAddresses, moc: moc), let root = moc.performAndWait({ mainShare.root }) else {
                Log.error(error: Errors.noMainShare, domain: .fileProvider)
                return .failure(Errors.noMainShare)
            }
            Log.info("Got item ROOT", domain: .fileProvider)
            do {
                let item = try NodeItem(node: root)
                return .success(item)
            } catch {
                return .failure(Errors.itemCannotBeCreated)
            }

        case .workingSet:
            Log.info("Getting item WORKING_SET does not make sense", domain: .fileProvider)
            return .failure(Errors.requestedItemForWorkingSet(identifier: identifier))

        case .trashContainer:
            Log.info("Getting item TRASH does not make sense", domain: .fileProvider)
            return .failure(Errors.requestedItemForTrash(identifier: identifier))

        default:
            guard let nodeId = NodeIdentifier(identifier) else {
                Log.error(error: Errors.nodeIdentifierNotFound(identifier: identifier), domain: .fileProvider)
                return .failure(Errors.nodeIdentifierNotFound(identifier: identifier))
            }
            guard let node = fileSystemSlot.getNode(nodeId, moc: moc) else {
                Log.error(error: Errors.nodeNotFound(identifier: identifier), domain: .fileProvider)
                return .failure(Errors.nodeNotFound(identifier: identifier))
            }
            let (nodeState, isTrashInheriting) = moc.performAndWait { (node.state, node.isTrashInheriting) }
            guard nodeState != .deleted, !isTrashInheriting else {
                // We don't want trashed items to display locally (disassociated items are
                // no longer managed by the File Provider and so don't get asked for)
                return .failure(Errors.nodeFoundInTrash(identifier: identifier))
            }
            do {
                let item = try NodeItem(node: node)
                Log.debug("Got item \(~item)", domain: .fileProvider)
                return .success(item)
            } catch {
                return .failure(Errors.itemCannotBeCreated)
            }
        }
    }
}
#endif
