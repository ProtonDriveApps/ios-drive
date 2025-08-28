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

public struct PhotoListingId: Equatable, Hashable {
    let primary: PhotoId
    let secondary: [PhotoId]

    var allIds: [PhotoId] {
        [primary] + secondary
    }
}

public protocol PhotosSelectionController {
    // Trigger when any change happens, e.g. add/ remove/ start/ cancel...etc
    var updatePublisher: AnyPublisher<Void, Never> { get }
    // Trigger when `finalized` is called
    var finalizedPublisher: AnyPublisher<Set<PhotoListingId>, Never> { get }
    func isSelecting() -> Bool
    func start(selectedID: Set<PhotoListingId>)
    func cancel()
    func finalized()
    func toggle(id: PhotoListingId)
    func select(ids: Set<PhotoListingId>)
    func deselectAll()
    func getPrimaryIds() -> Set<PhotoId>
    func getAllIds() -> Set<PhotoId>
    func getPhotoListingIDs() -> Set<PhotoListingId>
}

final class LocalPhotosSelectionController: PhotosSelectionController {
    private let subject = PassthroughSubject<Void, Never>()
    private let finalizeSubject = PassthroughSubject<Set<PhotoListingId>, Never>()
    private var isSelectingValue = false
    private var ids = Set<PhotoListingId>()

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    var finalizedPublisher: AnyPublisher<Set<PhotoListingId>, Never> {
        finalizeSubject.eraseToAnyPublisher()
    }

    func isSelecting() -> Bool {
        isSelectingValue
    }

    func start(selectedID: Set<PhotoListingId>) {
        ids = selectedID
        isSelectingValue = true
        subject.send()
    }

    func cancel() {
        isSelectingValue = false
        ids.removeAll()
        subject.send()
    }

    func finalized() {
        finalizeSubject.send(ids)
        cancel()
    }

    func toggle(id: PhotoListingId) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        subject.send()
    }

    func select(ids: Set<PhotoListingId>) {
        self.ids = ids
        subject.send()
    }

    func deselectAll() {
        ids.removeAll()
        subject.send()
    }

    func getAllIds() -> Set<PhotoId> {
        Set(ids.flatMap(\.allIds))
    }

    func getPrimaryIds() -> Set<PhotoId> {
        Set(ids.map(\.primary))
    }

    func getPhotoListingIDs() -> Set<PhotoListingId> {
        ids
    }
}
