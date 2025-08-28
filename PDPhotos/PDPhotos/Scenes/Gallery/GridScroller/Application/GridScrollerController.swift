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

import Combine
import Foundation
import PDCore

struct GridScrollerCurrentItem {
    let date: Date
    let index: Int
}

protocol GridScrollerControllerProtocol {
    var items: AnyPublisher<[GridScrollerYear], Never> { get }
    var isScrolling: AnyPublisher<Bool, Never> { get }
    var selectedId: AnyPublisher<AnyVolumeIdentifier, Never> { get }
    var currentItem: AnyPublisher<GridScrollerCurrentItem, Never> { get }
    func setScrolling()
    func setCurrentItem(_ item: PhotoGridViewItem)
    func setCurrentIndex(_ index: Int)
    func setAvailableCount(_ availableCount: Int)
}

final class GridScrollerController: GridScrollerControllerProtocol {
    private let listController: PhotosListControllerProtocol
    private let fetchingController: PhotosListFetchingControllerProtocol
    private let strategy: GridScrollerItemsStrategyProtocol
    private let itemsSubject = CurrentValueSubject<[GridScrollerYear], Never>([])
    private let isScrollingSubject = PassthroughSubject<Bool, Never>()
    private let selectedIdSubject = PassthroughSubject<AnyVolumeIdentifier, Never>()
    private let currentItemSubject = PassthroughSubject<GridScrollerCurrentItem, Never>()
    private var countSubject = PassthroughSubject<Int, Never>()
    private var cancellables = Set<AnyCancellable>()

    var items: AnyPublisher<[GridScrollerYear], Never> {
        itemsSubject.eraseToAnyPublisher()
    }

    var isScrolling: AnyPublisher<Bool, Never> {
        isScrollingSubject.eraseToAnyPublisher()
    }

    var selectedId: AnyPublisher<AnyVolumeIdentifier, Never> {
        selectedIdSubject.eraseToAnyPublisher()
    }

    var currentItem: AnyPublisher<GridScrollerCurrentItem, Never> {
        currentItemSubject.eraseToAnyPublisher()
    }

    init(listController: PhotosListControllerProtocol, fetchingController: PhotosListFetchingControllerProtocol, strategy: GridScrollerItemsStrategyProtocol) {
        self.listController = listController
        self.fetchingController = fetchingController
        self.strategy = strategy
        subscribeToUpdates()
    }

    func setScrolling() {
        isScrollingSubject.send(true)
    }

    func setCurrentItem(_ item: PhotoGridViewItem) {
        let sectionItems = itemsSubject.value.flatMap(\.items)
        guard !sectionItems.isEmpty else {
            return
        }

        var currentItem: GridScrollerCurrentItem?
        var index = 0
        // `sectionItems` are ordered by date from most recent to oldest
        for section in sectionItems {
            if section.startDate <= item.captureTime || index == sectionItems.count - 1 {
                // either
                // - item is same or older than `startDate` or same or newer than `endDate`
                // - fallback to last item if necessary
                currentItem = GridScrollerCurrentItem(date: section.startDate, index: index)
                break
            }
            index += 1
        }
        if let currentItem {
            currentItemSubject.send(currentItem)
        }
    }

    func setCurrentIndex(_ index: Int) {
        let items = itemsSubject.value.flatMap(\.items)
        if let item = items[safe: index] {
            let currentItem = GridScrollerCurrentItem(date: item.startDate, index: index)
            currentItemSubject.send(currentItem)
            selectedIdSubject.send(item.startId)
        }
    }

    func setAvailableCount(_ availableCount: Int) {
        countSubject.send(availableCount)
    }

    private func subscribeToUpdates() {
        fetchingController.isLoading
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.itemsSubject.send([])
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(listController.sections, countSubject, fetchingController.lastAnchor)
            .filter { !$2.hasMore }
            .sink { [weak self] sections, count, _ in
                self?.updateItems(sections: sections, count: count)
            }
            .store(in: &cancellables)
    }

    /// `sections` - listings grouped by month
    /// `count` - maximal displayable number of items
    private func updateItems(sections: [PhotosListSection], count: Int) {
        let items = strategy.makeItems(months: sections, maximalCount: count)
        itemsSubject.send(items)
    }
}
