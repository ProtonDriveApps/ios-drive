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

protocol PhotosStateTitlesViewModelProtocol: ObservableObject {
    var item: PhotosStateTitle? { get }
}

final class PhotosStateTitlesViewModel: PhotosStateTitlesViewModelProtocol {
    private let timerFactory: TimerFactory
    private var items: [PhotosStateTitle] = []
    private var cancellable: AnyCancellable?

    @Published var item: PhotosStateTitle?

    init(timerFactory: TimerFactory) {
        self.timerFactory = timerFactory
    }

    func set(_ items: [PhotosStateTitle]) {
        guard self.items != items else {
            return
        }

        self.items = items
        item = items.first

        guard items.count > 1 else {
            cancellable?.cancel()
            return
        }

        guard cancellable == nil else {
            return
        }

        cancellable = timerFactory.makeTimer(interval: 2)
            .sink { [weak self] in
                self?.update()
            }
    }

    deinit {
        cancellable?.cancel()
    }

    private func update() {
        guard let item else {
            return
        }

        guard let index = items.firstIndex(of: item) else {
            return
        }

        if items.indices.contains(index + 1) {
            self.item = items[index + 1]
        } else {
            self.item = items.first
        }
    }
}
