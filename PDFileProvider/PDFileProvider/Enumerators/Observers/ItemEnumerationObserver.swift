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
import PDCore
import Combine
import PDLocalization

private actor ItemEnumerationState {
    /// How many enumerations have started.
    private var startedCount = 0

    private(set) var itemsEnumeratedSoFar = 0

    /// We don't know the actual percentage completed, because we don't know how many enumerations there will be.
    /// Instead, we start by with 50% (1/2), and then increment to 2/3, 3/4, 4/5, 5/6 until done.
    fileprivate var percentage: Int {
        return 100 * startedCount / (startedCount + 1)
    }

    fileprivate func start() {
        startedCount += 1
        Log.trace("ItemEnumerationState: start:\(startedCount)")
    }

    fileprivate func reset() {
        Log.trace("ItemEnumerationState: reset")
        startedCount = 0
        itemsEnumeratedSoFar = 0
    }

    fileprivate func updateEnumeratedSoFar(count: Int) {
        itemsEnumeratedSoFar += count
        Log.trace("Added \(count), total = \(itemsEnumeratedSoFar)")
    }
}

public class ItemEnumerationObserver: BaseEnumerationObserver, NSFileProviderEnumerationObserver {
    public static let enumerationSyncItemIdentifier = "enumerateItems"

    /// If the interval between enumerations is shorter than this value, they will show up in the tray app as one continous operation.
    private let intervalBetweenEnumerations: RunLoop.SchedulerTimeType.Stride = 5.0

    /// The enumeration summary will be deleted this many seconds after completion.
    private let intervalBeforeDeletion: RunLoop.SchedulerTimeType.Stride = 5.0

    private let id = UUID().uuidString

    private let enumerationState = ItemEnumerationState()

    private var subject = PassthroughSubject<Int, Never>()
    private var cancellables = Set<AnyCancellable>()

    override public init(syncStorage: SyncStorageManager) {
        Log.trace()

        super.init(syncStorage: syncStorage)
        setupCompletionSubscriber()
    }

    /// Start enumerating.
    /// Called on random thread.
    public func didStartEnumeratingItems(name: String) {
        assert(!Thread.isMainThread)
        Task {
            await enumerationState.start()
            Log.trace("sending 0")
            subject.send(0)
            let percentage = await enumerationState.percentage
            Log.trace("\(id) Started and showing: \(percentage)%")
            updateSyncItem(progress: percentage)
        }
    }

    // MARK: - NSFileProviderEnumerationObserver

    /// Reports the items enumerated in the current batch.
    public func didEnumerate(_ updatedItems: [any NSFileProviderItemProtocol]) {
        Log.trace("\(id) updatedItems: \(updatedItems.count)")
        Task {
            await enumerationState.updateEnumeratedSoFar(count: updatedItems.count)
        }
    }

    /// Finished enumerating.
    /// Usually called on main thread, except after logging in.
    public func finishEnumerating(upTo nextPage: NSFileProviderPage?) {
        Task {
            let percentage = await enumerationState.percentage
            let itemsEnumeratedSoFar = await enumerationState.itemsEnumeratedSoFar

            Log.trace("\(id), Percentage: \(percentage)%, enumerated: \(itemsEnumeratedSoFar)")

            updateSyncItem(progress: percentage)
            subject.send(itemsEnumeratedSoFar)
        }
    }

    /// Finished enumerating with error.
    public func finishEnumeratingWithError(_ error: any Error) {
        Log.trace("\(id) error: \(error.localizedDescription)")
        updateSyncItem(error: error)
    }

    // MARK: - Private

    private func setupCompletionSubscriber() {
        subject
            .handleEvents(receiveOutput: { value in
                Log.trace("Before debounce: \(value)")
            })
            .debounce(for: .seconds(intervalBetweenEnumerations.timeInterval), scheduler: RunLoop.main)
            .sink { [unowned self] value in
                Task {
                    Log.trace("After debounce: \(value)")
                    await self.didFinishAllEnumerations(value: value)
                }
            }
            .store(in: &cancellables)

        subject
            .handleEvents(receiveOutput: { value in
                Log.trace("Before deletion debounce: \(value)")
            })
            .debounce(for: .seconds(intervalBeforeDeletion.timeInterval), scheduler: RunLoop.main)
            .sink { [unowned self] value in
                Task {
                    Log.trace("After deletion debounce: \(value)")
                    await deleteAfterCompletion()
                }
            }
            .store(in: &cancellables)
    }

    /// Called after the last didStartEnumerating/didFinishEnumerating pair in a group of pairs separated by less than `intervalBetweenEnumerations`.
    private func didFinishAllEnumerations(value: Int) async {
        let itemsEnumeratedSoFar = await enumerationState.itemsEnumeratedSoFar
        guard await value == enumerationState.itemsEnumeratedSoFar else {
            Log.trace("Returning because \(value) != \(itemsEnumeratedSoFar)")
            return
        }

        Log.trace("Wrapping up: \(value)")

        updateSyncItem(progress: 100)
        await enumerationState.reset()
    }

    /// Called `intervalBeforeDeletion` seconds after `didFinish`.
    private func deleteAfterCompletion() async {
        Log.trace()
         syncStorage.delete(id: Self.enumerationSyncItemIdentifier)
    }

    private func updateSyncItem(progress: Int? = nil, error: Error? = nil) {
        Task {
            let progressState: SyncItemState = progress == 100 ? .finished : .inProgress
            let computedState: SyncItemState = error == nil ? progressState : .errored
            let computedProgress: Int = error == nil ? (progress ?? 0) : 0
            let itemsEnumeratedSoFar = await self.enumerationState.itemsEnumeratedSoFar
#if os(macOS)
            let filename = Localization.menu_status_sync_enumerating(itemsEnumerated: itemsEnumeratedSoFar)
#else
            let filename = Localization.listing_local_files
#endif

            Log.trace("computedState: \(computedState), computedProgress: \(computedProgress)")

            let item = ReportableSyncItem(
                id: Self.enumerationSyncItemIdentifier,
                modificationTime: Date.now,
                filename: filename,
                location: nil,
                mimeType: nil,
                fileSize: nil,
                operation: .enumerateItems,
                state: computedState,
                progress: computedProgress,
                errorDescription: error?.localizedDescription)
            syncStorage.upsert(item)
        }
    }

    deinit {
        Log.trace(id)
    }
}
