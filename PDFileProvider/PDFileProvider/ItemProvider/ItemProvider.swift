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
import os.log

public final class ItemProvider: LogObject {
    public static var osLog: OSLog = OSLog(subsystem: "ProtonDriveFileProvider", category: "ItemProvider")
    
    public init() { }
    
    @discardableResult
    public func item(for identifier: NSFileProviderItemIdentifier,
                     creatorAddresses: Set<String>,
                     slot: FileSystemSlot,
                     completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress
    {
        let (item, error) = self.item(for: identifier, creatorAddresses: creatorAddresses, slot: slot)
        completionHandler(item, error)
        return Progress()
    }
    
    /// Creator is relevant only for root folder
    public func item(for identifier: NSFileProviderItemIdentifier, creatorAddresses: Set<String>, slot: FileSystemSlot) -> (NSFileProviderItem?, Error?) {
        switch identifier {
        case .rootContainer:
            guard !creatorAddresses.isEmpty, let mainShare = slot.getMainShare(of: creatorAddresses), let root = mainShare.root else {
                ConsoleLogger.shared?.log(Errors.noMainShare, osLogType: Self.self)
                return (nil, Errors.noMainShare)
            }
            ConsoleLogger.shared?.log("Got item ROOT", osLogType: Self.self)
            return (NodeItem(node: root), nil)

        case .workingSet:
            ConsoleLogger.shared?.log("Getting item WORKING_SET does not make sense", osLogType: Self.self)
            return (nil, Errors.requestedItemForWorkingSet)
            
        case .trashContainer:
            ConsoleLogger.shared?.log("Getting item TRASH does not make sense", osLogType: Self.self)
            return (nil, Errors.requestedItemForTrash)
        
        default:
            guard let nodeId = NodeIdentifier(identifier), let node = slot.getNode(nodeId) else {
                ConsoleLogger.shared?.log(Errors.nodeNotFound, osLogType: Self.self)
                return (nil, Errors.nodeNotFound)
            }
            let item = NodeItem(node: node)
            ConsoleLogger.shared?.log("Got item \(~item)", osLogType: Self.self)
            return (item, nil)
        }
    }
    
    @discardableResult
    public func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier,
                              version requestedVersion: NSFileProviderItemVersion? = nil,
                              slot: FileSystemSlot,
                              downloader: Downloader,
                              completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress
    {
        ConsoleLogger.shared?.log("Start fetching contents for \(itemIdentifier)", osLogType: Self.self)
        guard let fileId = NodeIdentifier(itemIdentifier), let file = slot.getNode(fileId) as? File else {
            ConsoleLogger.shared?.log(Errors.nodeNotFound, osLogType: Self.self)
            completionHandler(nil, nil, Errors.nodeNotFound)
            return Progress()
        }
        ConsoleLogger.shared?.log("- identifier \(itemIdentifier) stands for \(~file)", osLogType: Self.self)
        
        // check if cyphertext of active revision is already available locally and can be decrypted
        if let revision = file.activeRevision, revision.blocksAreValid(), let clearUrl = try? revision.decryptFile() {
            ConsoleLogger.shared?.log("Found cached cypherdata for \(~file), prepared cleartext at temp location", osLogType: Self.self)
            completionHandler(clearUrl, NodeItem(node: file), nil)
            return Progress()
        }
        
        // if not cached or can not decrypt - proceed to download
        ConsoleLogger.shared?.log("Schedule download operation for \(~file)", osLogType: Self.self)
        let operation = downloader.scheduleDownloadFileProvider(cypherdataFor: file) { result in
            switch result {
            case let .success(file) where file.activeRevision != nil:
                do {
                    let url = try file.activeRevision!.decryptFile()
                    ConsoleLogger.shared?.log("Prepared cleartext content of \(~file) at temp location", osLogType: Self.self)
                    completionHandler(url, NodeItem(node: file), nil)
                } catch {
                    ConsoleLogger.shared?.log(error, osLogType: Self.self)
                    return completionHandler(nil, nil, error)
                }
                
            case let .failure(error):
                ConsoleLogger.shared?.log(error, osLogType: Self.self)
                return completionHandler(nil, nil, error)
                
            default:
                ConsoleLogger.shared?.log(Errors.revisionNotFound, osLogType: Self.self)
                return completionHandler(nil, nil, Errors.revisionNotFound)
            }
        }

        return (operation as? OperationWithProgress)?.progress ?? Progress()
    }
}
