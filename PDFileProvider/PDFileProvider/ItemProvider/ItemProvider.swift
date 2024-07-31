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
import PDCore
import CoreData

public final class ItemProvider {
    private let decryptor = RevisionDecryptor()
    
    public init() { }
    
    @discardableResult
    public func item(for identifier: NSFileProviderItemIdentifier,
                     creatorAddresses: Set<String>,
                     slot: FileSystemSlot,
                     completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress
    {
        let task = Task { [weak self] in
            guard !Task.isCancelled else { return }
            guard let (item, error) = self?.item(for: identifier, creatorAddresses: creatorAddresses, slot: slot)
            else { return }
            guard !Task.isCancelled else { return }
            completionHandler(item, error)
        }
        return Progress {
            Log.info("Item for identifier cancelled", domain: .fileProvider)
            task.cancel()
            completionHandler(nil, CocoaError(.userCancelled))
        }
    }
    
    /// Creator is relevant only for root folder
    public func item(for identifier: NSFileProviderItemIdentifier, creatorAddresses: Set<String>, slot: FileSystemSlot) -> (NSFileProviderItem?, Error?) {
        switch identifier {
        case .rootContainer:
            guard !creatorAddresses.isEmpty, let mainShare = slot.getMainShare(of: creatorAddresses), let root = slot.moc.performAndWait({ mainShare.root }) else {
                Log.error(Errors.noMainShare.localizedDescription, domain: .fileProvider)
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
            guard let nodeId = NodeIdentifier(identifier), let node = slot.getNode(nodeId) else {
                Log.error(Errors.nodeNotFound.localizedDescription, domain: .fileProvider)
                return (nil, Errors.nodeNotFound)
            }
            guard node.state != .deleted && !node.isTrashInheriting else {
                // We don't want trashed items to display locally (disassociated items are
                // no longer managed by the File Provider and so don't get asked for)
                return (nil, Errors.nodeNotFound)
            }

            do {
                let item = try NodeItem(node: node)
                Log.info("Got item \(~item)", domain: .fileProvider)
                return (item, nil)
            } catch {
                return (nil, Errors.itemCannotBeCreated)
            }
        }
    }
    
    @discardableResult
    public func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier,
                              version requestedVersion: NSFileProviderItemVersion? = nil,
                              slot: FileSystemSlot,
                              downloader: Downloader,
                              storage: StorageManager,
                              completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress
    {
        Log.info("Start fetching contents for \(itemIdentifier)", domain: .fileProvider)
        
        let moc = storage.newBackgroundContext()
        guard let fileId = NodeIdentifier(itemIdentifier), let file = slot.getNode(fileId, moc: moc) as? File else {
            Log.error(Errors.nodeNotFound, domain: .fileProvider)
            completionHandler(nil, nil, Errors.nodeNotFound)
            return Progress {
                Log.info("Fetch contents for \(itemIdentifier) cancelled", domain: .fileProvider)
                completionHandler(nil, nil, CocoaError(.userCancelled))
            }
        }
        Log.info("- identifier \(itemIdentifier) stands for \(~file)", domain: .fileProvider)
        
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
                    self?.downloadAndDecrypt(file, downloader: downloader, moc: moc, completionHandler: completionHandler)
                }
            }
            return Progress {
                Log.info("Fetch contents for \(itemIdentifier) cancelled", domain: .fileProvider)
                task.cancel()
                completionHandler(nil, nil, CocoaError(.userCancelled))
            }
        } else {
            // if not cached, proceed to download
            return downloadAndDecrypt(file, downloader: downloader, moc: moc, completionHandler: completionHandler)
        }
    }
    
    @discardableResult
    private func downloadAndDecrypt(_ file: File,
                                    downloader: Downloader,
                                    moc: NSManagedObjectContext,
                                    completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        Log.info("Schedule download operation for \(~file)", domain: .fileProvider)
        let operation = downloader.scheduleDownloadFileProvider(cypherdataFor: file) { [unowned self] result in
            switch result {
            case let .success(fileInOtherMoc):
                let file = fileInOtherMoc.in(moc: moc)

                guard let revision = cachedRevision(for: file, on: moc) else {
                    Log.error(Errors.revisionNotFound.localizedDescription, domain: .fileProvider)
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
                        Log.error(error.localizedDescription, domain: .fileProvider)
                        completionHandler(nil, nil, error)
                    }
                }
                
            case let .failure(error):
                Log.error(error.localizedDescription, domain: .fileProvider)
                completionHandler(nil, nil, error)
            }
        }

        return (operation as? OperationWithProgress).map {
            $0.progress.setOneTimeCancellationHandler { [weak operation] in
                Log.info("Download and decrypt operation cancelled", domain: .fileProvider)
                operation?.cancel()
                completionHandler(nil, nil, CocoaError(.userCancelled))
            }
        } ?? Progress { [weak operation] in
            Log.info("Download and decrypt operation cancelled", domain: .fileProvider)
            operation?.cancel()
            completionHandler(nil, nil, CocoaError(.userCancelled))
        }
    }
    
    private func cachedRevision(for file: File, on moc: NSManagedObjectContext) -> Revision? {
        return moc.performAndWait {
            if let revision = file.activeRevision, revision.blocksAreValid() {
                return revision
            } else {
                return nil
            }
        }
    }
}
