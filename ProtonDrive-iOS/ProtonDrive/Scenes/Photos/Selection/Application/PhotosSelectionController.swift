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

protocol PhotosSelectionController {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    func isSelecting() -> Bool
    func start()
    func cancel()
    func toggle(id: PhotoId)
    func select(ids: Set<PhotoId>)
    func deselectAll()
    func getIds() -> Set<PhotoId>
}

final class LocalPhotosSelectionController: PhotosSelectionController {
    private let subject = PassthroughSubject<Void, Never>()
    private var isSelectingValue = false
    private var ids = Set<PhotoId>()

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    func isSelecting() -> Bool {
        isSelectingValue
    }

    func start() {
        isSelectingValue = true
        subject.send()
    }

    func cancel() {
        isSelectingValue = false
        ids.removeAll()
        subject.send()
    }

    func toggle(id: PhotoId) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        subject.send()
    }

    func select(ids: Set<PhotoId>) {
        self.ids = ids
        subject.send()
    }

    func deselectAll() {
        ids.removeAll()
        subject.send()
    }

    func getIds() -> Set<PhotoId> {
        ids
    }
}
