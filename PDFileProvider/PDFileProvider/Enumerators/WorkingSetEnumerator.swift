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

public final class WorkingSetEnumerator: NSObject, NSFileProviderEnumerator, EnumeratorWithItemsFromDB {
    typealias Model = ActivityModel

    private weak var tower: Tower!
    let keepDownloadedManager: KeepDownloadedEnumerationManager
    let resyncEnumerationServiceProperty: ResyncEnumerationService

    private(set) var model: ActivityModel?
    var resyncEnumerationTask: Task<Void, Never>?

    private let pageSize: Int

    let enumerationObserver: EnumerationObserverProtocol?

    let displayChangeEnumerationDetails: Bool

    public init(tower: Tower,
                keepDownloadedManager: KeepDownloadedEnumerationManager,
                resyncEnumerationService: ResyncEnumerationService,
                pageSize: Int = 5_000,
                enumerationObserver: EnumerationObserverProtocol? = nil,
                displayChangeEnumerationDetails: Bool = false) {
        Log.trace()
        self.tower = tower
        self.keepDownloadedManager = keepDownloadedManager
        self.resyncEnumerationServiceProperty = resyncEnumerationService
        self.pageSize = pageSize
        self.enumerationObserver = enumerationObserver
        self.displayChangeEnumerationDetails = displayChangeEnumerationDetails

        super.init()
    }

    public func invalidate() {
        Log.trace()
        resyncEnumerationTask?.cancel()
        resyncEnumerationServiceProperty.diffCache.clear()
        self.model = nil
    }

    func reinitializeModelIfNeeded() throws -> ActivityModel {
        if let model { return model }

        Log.trace()
        let model = try ActivityModel(tower: tower)
        self.model = model
        return model
    }

    private func clearWorkingSetEnumerationFlagIfStillSet() {
        guard resyncEnumerationServiceProperty.workingSetEnumerationInProgress == true else { return }
        resyncEnumerationServiceProperty.workingSetEnumerationInProgress = false
    }

    // MARK: Enumeration

    public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Log.event(.enumerateItems(.started(.init(containerType: .workingSet, pageNumber: page.int))))

        // Clear the flag only when enumeration terminates (last page emitted or error thrown),
        // not at the return of every `enumerateItems` call. Otherwise the coordinator would stop
        // waiting after just the first page, while the working set may span many more pages.
        let clearFlagIfStillSet: () -> Void = { [weak self] in self?.clearWorkingSetEnumerationFlagIfStillSet() }
        let completionHook = WorkingSetEnumerationCompletionHook(onFinish: clearFlagIfStillSet)

        let observers: [NSFileProviderEnumerationObserver] = [
            observer,
            enumerationObserver?.items as? NSFileProviderEnumerationObserver,
            completionHook
        ].compactMap { $0 }

        let pageNumber = page.rawValue.first ?? 0

        enumerationObserver?.items.didStartEnumeratingItems(name: "Page \(pageNumber.description)")

        let model: ActivityModel
        do {
            model = try self.reinitializeModelIfNeeded()
        } catch {
            observer.finishEnumeratingWithError(Errors.mapLegacyErrorToFileProviderError(Errors.failedToCreateModel))
            clearFlagIfStillSet()
            Log.event(.enumerateItems(.failed(.init(
                containerType: .workingSet,
                errorMessage: "Failed to enumerate items due to model failing to be created"
            ))))
            // if we cannot create a model, there's no point in accessing the model for enumeration later
            return
        }
        model.loadFromCache()
        self.fetchPageFromDB(.workingSet, page.int, pageSize: pageSize, observers: observers, model: model)
    }

    // MARK: Changes

    public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        Log.trace("Working set enumeration", domain: .enumerating)
        do {
            let model = try reinitializeModelIfNeeded()
            self.currentSyncAnchor(shareID: model.shareID, completionHandler)
        } catch {
            Log.error("Failed to get currentSyncAnchor due to model failing to be created", error: error, domain: .enumerating)
            completionHandler(nil)
        }
    }

    public func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        do {
            Log.trace("Working set enumeration", domain: .enumerating)
            let observers = [observer, enumerationObserver?.changes as? NSFileProviderChangeObserver].compactMap { $0 }
            let model = try self.reinitializeModelIfNeeded()
            self.enumerateChanges(model.shareID, .workingSet, observers, syncAnchor, "WorkingSetEnumerator")
        } catch {
            observer.finishEnumeratingWithError(Errors.mapLegacyErrorToFileProviderError(Errors.failedToCreateModel))
            // match enumerateItems: unblock FullResyncCoordinator's working-set wait instead of letting it time out
            clearWorkingSetEnumerationFlagIfStillSet()
            Log.error("Failed to enumerate changes due to model failing to be created", error: error, domain: .enumerating)
            // if we cannot create a model, there's no point in accessing the model for enumeration later
            return
        }
    }
}

extension WorkingSetEnumerator: EnumeratorWithChanges {
    var resyncEnumerationService: ResyncEnumerationService? { resyncEnumerationServiceProperty }
    var eventsManager: EventsSystemManager { self.tower }
    var fileSystemSlot: FileSystemSlot { self.tower.fileSystemSlot! }
    var cloudSlot: CloudSlotProtocol { self.tower.cloudSlot! }
}

private final class WorkingSetEnumerationCompletionHook: NSObject, NSFileProviderEnumerationObserver {
    private let onFinish: () -> Void
    private var hasFinished = false

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func didEnumerate(_ updatedItems: [any NSFileProviderItemProtocol]) {}

    func finishEnumerating(upTo nextPage: NSFileProviderPage?) {
        guard nextPage == nil, !hasFinished else { return }
        hasFinished = true
        onFinish()
    }

    func finishEnumeratingWithError(_ error: any Error) {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }
}
