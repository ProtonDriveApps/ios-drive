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
import PDCore

protocol SortingViewModel: AnyObject {
    var sorting: SortPreference { get set }
    func onSortingChanged()
}
extension SortingViewModel where Self: FinderViewModel, Self.Model: NodesSorting, Self: CancellableStoring {
    func subscribeToSort() {
        self.model.sortingPublisher
        .receive(on: DispatchQueue.main)
        .sink { [weak self] sort in
            guard let self = self, self.sorting != sort else { return }
            self.sorting = sort
            if self.isVisible {
                self.onSortingChanged()
            }
        }
        .store(in: &cancellables)
    }
}

protocol LayoutChangingViewModel: AnyObject {
    var layout: Layout { get set }
}

extension LayoutChangingViewModel where Self: FinderViewModel, Self: CancellableStoring, Self.Model: LayoutChanging {
    
    func subscribeToLayoutChanges() {
        model.layoutPublisher
        .filter { [weak self] _ in self?.isVisible == true }
        .map(Layout.init)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] layout in
            guard let self = self, self.layout != layout else { return }
            self.layout = layout
        }
        .store(in: &cancellables)
    }

    func changeLayout() {
        model.changeLayoutPreference(to: layout.next.asPreference)
    }
}
