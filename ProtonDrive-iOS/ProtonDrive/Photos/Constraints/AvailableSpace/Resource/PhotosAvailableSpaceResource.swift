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

import Combine
import Foundation
import PDCore

protocol PhotosAvailableSpaceResource {
    var availableSpace: AnyPublisher<Int, Never> { get }
    func execute()
    func cancel()
}

final class ConcretePhotosAvailableSpaceResource: PhotosAvailableSpaceResource {
    private let observer: FetchedResultsControllerObserver<Photo>
    private var subject = PassthroughSubject<Int, Never>()
    private var queue = DispatchQueue(label: "ConcretePhotosAvailableSpaceResource", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    private var workItem: DispatchWorkItem?

    var availableSpace: AnyPublisher<Int, Never> {
        subject
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(observer: FetchedResultsControllerObserver<Photo>) {
        self.observer = observer
    }

    func execute() {
        cancel()

        observer.getPublisher()
            .map { $0.count }
            .removeDuplicates()
            .map { _ in Void() }
            .receive(on: queue)
            .sink { [weak self] size in
                self?.handleUpdate()
            }
            .store(in: &cancellables)
    }

    private func handleUpdate() {
        // We don't get automatic available space updates, so we recalculate every time the upload changes or timer ticks.
        // Should only run while app is in foreground.
        let space = getRemainingSpace()
        if space < Constants.photosNecessaryFreeStorage * 2 { // Only logging critical proximity.
            Log.info("Updated remaining space: \(space)", domain: .photosProcessing)
        }
        subject.send(space)
        scheduleNextUpdate()
    }

    private func scheduleNextUpdate() {
        workItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleUpdate()
        }
        self.workItem = workItem
        queue.asyncAfter(deadline: .now() + .seconds(5), execute: workItem)
    }

    private func getRemainingSpace() -> Int {
        let url = FileManager.default.temporaryDirectory
        // `PrivacyInfo.xcprivacy` needs to be kept/maintained in order to use `volumeAvailableCapacityForImportantUsageKey` api.
        // There's an issue with logging (<= iOS 16) - every time we request this, we get `CDPurgeableResultCache _recentPurgeableTotals no result for` in the console.
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let size = values?.volumeAvailableCapacityForImportantUsage
        return (Int(size ?? 0) / 1_000_000) * 1_000_000 // Rounding to MB
    }

    func cancel() {
        workItem?.cancel()
        cancellables.removeAll()
    }
}
