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

import CoreData

public final class PersistentHistoryObserver {
    public typealias Transactions = [NSPersistentHistoryTransaction]
    
    public let transactions: AsyncStream<Transactions>

    private let persistentContainer: NSPersistentContainer
    private let target: AppTarget
    private let userDefaults: UserDefaults
    private var transactionsContinuation: AsyncStream<Transactions>.Continuation?

    /// An operation queue for processing history transactions.
    private lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    public init(target: AppTarget, 
                suite: SettingsStorageSuite,
                syncStorage: SyncStorageManager) {
        self.target = target
        self.userDefaults = suite.userDefaults
        self.persistentContainer = syncStorage.persistentContainer

        var continuation: AsyncStream<Transactions>.Continuation?
        self.transactions = AsyncStream<Transactions> { continuation = $0 }
        self.transactionsContinuation = continuation
    }

    public func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(processStoreRemoteChanges), name: .NSPersistentStoreRemoteChange, object: persistentContainer.persistentStoreCoordinator)
    }

    /// Process persistent history to merge changes from other coordinators.
    @objc private func processStoreRemoteChanges(_ notification: Notification) {
        historyQueue.addOperation { [weak self] in
            self?.processPersistentHistory()
        }
    }

    func clean(everything: Bool = false,
               context: NSManagedObjectContext? = nil) {
        do {
            let moc = context ?? persistentContainer.newBackgroundContext()
            let cleaner = PersistentHistoryCleaner(
                context: moc, targets: AppTarget.allCases, userDefaults: userDefaults)
            if everything {
                try cleaner.cleanEverything()
            } else {
                try cleaner.clean()
            }
        } catch {
            Log.error("Failed to clean persistent history: \(error.localizedDescription)", domain: .storage)
        }
    }

    func resetTimestamp(context: NSManagedObjectContext? = nil) {
        let moc = context ?? persistentContainer.newBackgroundContext()
        let cleaner = PersistentHistoryCleaner(
            context: moc, targets: AppTarget.allCases, userDefaults: userDefaults)
        cleaner.resetTimestamp()
    }

    @objc private func processPersistentHistory() {
        let context = persistentContainer.newBackgroundContext()
        
        let transactions = context.performAndWait {
            do {
                let merger = PersistentHistoryMerger(
                    backgroundContext: context, viewContext: persistentContainer.viewContext,
                    currentTarget: target, userDefaults: userDefaults)
                return try merger.merge()
            } catch {
                Log.error("Failed to merge persistent history: \(error.localizedDescription)", domain: .storage)
                return []
            }
        }
        clean(context: context)

        self.transactionsContinuation?.yield(transactions)
    }
}
