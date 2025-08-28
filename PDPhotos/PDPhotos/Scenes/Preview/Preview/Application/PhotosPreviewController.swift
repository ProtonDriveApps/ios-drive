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

protocol PhotosPreviewController: AnyObject {
    var updatePublisher: AnyPublisher<Void, Never> { get }
    var currentDeletedPublisher: AnyPublisher<PreviewDirection, Never> { get }
    func getCurrent() -> PhotoId?
    func getListing(id: PhotoId) -> PhotoListing?
    func setCurrent(_ id: PhotoId)
    func getNext() -> PhotoId?
    func getPrevious() -> PhotoId?
}

final class ListingPhotosPreviewController: PhotosPreviewController {
    private let controller: PhotosListControllerProtocol
    private var cancellables = Set<AnyCancellable>()
    private var ids = [PhotoId]()
    private var currentId: PhotoId?
    private var isInitialized = false
    private let subject = PassthroughSubject<Void, Never>()
    private let currentDeletedSubject = PassthroughSubject<PreviewDirection, Never>()

    var updatePublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }
    var currentDeletedPublisher: AnyPublisher<PreviewDirection, Never> {
        currentDeletedSubject.eraseToAnyPublisher()
    }

    init(controller: PhotosListControllerProtocol, currentId: PhotoId) {
        self.controller = controller
        self.currentId = currentId
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        controller.sections
            .map { sections in
                sections.flatMap { section in
                    section.photos.map { $0.id }
                }
            }
            .removeDuplicates()
            .sink { [weak self] ids in
                self?.handleUpdate(ids)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(_ ids: [PhotoId]) {
        if !ids.isEmpty {
            isInitialized = true
        }
        if let currentId, !ids.contains(currentId), isInitialized {
            resetCurrentId()
        }
        self.ids = ids
        subject.send()

    }

    func getCurrent() -> PhotoId? {
        return currentId
    }

    func getListing(id: PhotoId) -> PhotoListing? {
        controller.getListings().first(where: { $0.id == id })
    }

    func setCurrent(_ id: PhotoId) {
        currentId = id
    }

    func getNext() -> PhotoId? {
        getId(with: 1)
    }

    func getPrevious() -> PhotoId? {
        getId(with: -1)
    }

    private func resetCurrentId() {
        if let next = getNext() {
            currentId = next
            currentDeletedSubject.send(.forward)
        } else if let previous = getPrevious() {
            currentId = previous
            currentDeletedSubject.send(.reverse)
        } else {
            currentId = nil
            currentDeletedSubject.send(.dismiss)
        }
    }

    private func getId(with delta: Int) -> PhotoId? {
        guard let currentId else { return nil }
        if let index = ids.firstIndex(of: currentId), ids.indices.contains(index + delta) {
            return ids[index + delta]
        } else {
            return nil
        }
    }
}

enum PreviewDirection {
    case forward
    case reverse
    case dismiss
}
