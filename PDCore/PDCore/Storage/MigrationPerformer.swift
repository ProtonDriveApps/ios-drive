// Copyright (c) 2024 Proton AG
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
import CoreData
import ProtonCoreCryptoGoInterface

@available(iOS, unavailable)
public final class MigrationPerformer {
    
    enum Errors: Error {
        case noMainKeyAvailable
    }
    
    private let keymaker: DriveKeymaker
    
    public init() {
        self.keymaker = DriveKeymaker(autolocker: nil, keychain: DriveKeychain())
    }
    
    public func performCleanup(in tower: Tower) async throws {
        try validateMainKey()
        
        let notifications = NotificationCenter.default.notifications(named: .restartApplication)
        
        Log.info("Cleanup: removing all caches", domain: .application)
        NotificationCenter.default.post(name: .nukeCacheExcludingEvents)
        
        // we don't need the notification object
        _ = await notifications.first { _ in true }
        
        Log.info("Cleanup: re-bootstrapping the state", domain: .application)
        try await tower.bootstrap()
    }
    
    public func hasFaultyNodes(in moc: NSManagedObjectContext) throws -> Bool {
        try validateMainKey()
        
        return try moc.performAndWait {
            let (faultyNodes, totalNodes) = try checkNodes(in: moc)
            if faultyNodes > 0, totalNodes != 0 {
                Log.info("Cleanup required: found \(faultyNodes) faulty Nodes of \(totalNodes) total", domain: .storage)
                return true
            }
            
            let (faultyShares, totalShares) = try checkShares(in: moc)
            if faultyShares > 0, totalShares != 0 {
                Log.info("Cleanup required: found \(faultyShares) faulty Shares of \(totalShares) total", domain: .storage)
                return true
            }
            
            let (faultyRevisions, totalRevisions) = try checkRevisions(in: moc)
            if faultyRevisions > 0, totalRevisions != 0 {
                Log.info("Cleanup required: found \(faultyRevisions) faulty Revisions of \(totalRevisions) total", domain: .storage)
                return true
            }
            
            return false
        }
    }
}

@available(iOS, unavailable)
extension MigrationPerformer {
    
    private func validateMainKey() throws {
        let mainKey = try? keymaker.mainKeyOrError
        if mainKey == nil {
            assertionFailure("MainKey should be accessible in order to perform migration")
            Log.error(error: MainKeyDecryptionError.decryption(Errors.noMainKeyAvailable), domain: .encryption)
            throw Errors.noMainKeyAvailable
        }
        Log.info("MainKey is available for MigrationPerformer operations", domain: .encryption)
    }
    
    private func checkRevisions(in moc: NSManagedObjectContext) throws -> (Int, Int) {
        let revisions = try moc.fetch(requestRevisions())
        let faulty = revisions.filter({ $0.signatureAddress == nil })
        return (faulty.count, revisions.count)
    }
    
    private func checkShares(in moc: NSManagedObjectContext) throws -> (Int, Int) {
        let shares = try moc.fetch(requestShares())
        let faulty = shares.filter({ $0.creator == nil })
        return (faulty.count, shares.count)
    }
    
    private func checkNodes(in moc: NSManagedObjectContext) throws -> (Int, Int) {
        let nodes = try moc.fetch(requestNodes())
        let faulty = nodes.filter({ $0.signatureEmail == nil })
        return (faulty.count, nodes.count)
    }

    private func requestRevisions() -> NSFetchRequest<Revision> {
        let fetchRequest = NSFetchRequest<Revision>()
        fetchRequest.entity = Revision.entity()
        fetchRequest.returnsObjectsAsFaults = true
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(Revision.signatureAddress))
        return fetchRequest
    }
    
    private func requestNodes() -> NSFetchRequest<Node> {
        let fetchRequest = NSFetchRequest<Node>()
        fetchRequest.entity = Node.entity()
        fetchRequest.returnsObjectsAsFaults = true
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(Node.signatureEmail))
        return fetchRequest
    }
    
    private func requestShares() -> NSFetchRequest<Share> {
        let fetchRequest = NSFetchRequest<Share>()
        fetchRequest.entity = Share.entity()
        fetchRequest.returnsObjectsAsFaults = true
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(Share.creator))
        return fetchRequest
    }
    
}
