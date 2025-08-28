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

enum GridScrollerMode {
    case scroller
    case items
}

struct GridScrollerYearViewItem {
    let id: AnyVolumeIdentifier
    let text: String
    let index: Int
}

protocol GridScrollerViewModelProtocol: ObservableObject {
    var isVisible: Bool { get }
    var mode: GridScrollerMode { get }
    var years: [GridScrollerYearViewItem] { get }
    var months: [String] { get }
    var currentIndex: Int { get }
    var count: Int { get }
    func continueDragging(_ index: Int)
    func endDragging()
    func setAvailableCount(_ count: Int)
}

final class GridScrollerViewModel: GridScrollerViewModelProtocol {
    private let controller: GridScrollerControllerProtocol
    private let debounceResource: DebounceResource
    private let dateFormatter: MonthAndYearFormatter
    private var cancellables = Set<AnyCancellable>()
    private var isDragging = false
    private var dotsCountSubject = PassthroughSubject<Int, Never>()

    @Published var isVisible: Bool = false
    @Published var mode: GridScrollerMode = .scroller
    @Published var years: [GridScrollerYearViewItem] = []
    @Published var months: [String] = []
    @Published var currentIndex: Int = 0
    @Published var count: Int = 0

    init(controller: GridScrollerControllerProtocol, debounceResource: DebounceResource, dateFormatter: MonthAndYearFormatter) {
        self.controller = controller
        self.debounceResource = debounceResource
        self.dateFormatter = dateFormatter
        subscribeToUpdates()
    }

    private func hideAfterDelay() {
        debounceResource.debounce(interval: 2) { [weak self] in
            self?.isVisible = false
        }
    }

    private func subscribeToUpdates() {
        controller.items
            .sink { [weak self] items in
                self?.handleItems(items)
            }
            .store(in: &cancellables)

        controller.isScrolling
            .filter { $0 }
            .sink { [weak self] _ in
                self?.setScrolling()
            }
            .store(in: &cancellables)

        controller.currentItem
            .sink { [weak self] item in
                self?.handleTopItem(item)
            }
            .store(in: &cancellables)
    }

    private func handleItems(_ years: [GridScrollerYear]) {
        var count = 0
        var viewYears = [GridScrollerYearViewItem]()
        var viewMonths = [String]()
        years.forEach { year in
            let index = count
            count += year.items.count
            year.items.forEach { item in
                let dateString = dateFormatter.formatMonthAndYear(date: item.startDate)
                viewMonths.append(dateString)
            }
            let viewYear = GridScrollerYearViewItem(
                id: year.startId,
                text: dateFormatter.formatYear(date: year.date),
                index: index
            )
            viewYears.append(viewYear)
        }
        
        self.count = count
        self.years = viewYears
        self.months = viewMonths
        if viewYears.isEmpty {
            isVisible = false
        }
    }

    private func handleTopItem(_ item: GridScrollerCurrentItem) {
        currentIndex = item.index
    }

    func continueDragging(_ index: Int) {
        if mode == .items {
            controller.setCurrentIndex(index)
        } else {
            mode = .items
        }
        isDragging = true
        debounceResource.cancel()
    }

    func endDragging() {
        isDragging = false
        mode = .scroller
        hideAfterDelay()
    }

    func setScrolling() {
        // Don't update if we don't have data
        guard !years.isEmpty else {
            return
        }
        if !isVisible {
            mode = .scroller
            isVisible = true
        }
        if !isDragging {
            hideAfterDelay()
        }
    }

    func setAvailableCount(_ count: Int) {
        controller.setAvailableCount(count)
    }
}
