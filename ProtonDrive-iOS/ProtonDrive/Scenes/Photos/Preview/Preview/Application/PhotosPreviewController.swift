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
    func getCurrent() -> PhotoId
    func setCurrent(_ id: PhotoId)
    func getNext() -> PhotoId?
    func getPrevious() -> PhotoId?
}

final class ListingPhotosPreviewController: PhotosPreviewController {
    private let controller: PhotosGalleryController
    private var cancellables = Set<AnyCancellable>()
    private var ids = [PhotoId]()
    private var currentId: PhotoId

    init(controller: PhotosGalleryController, currentId: PhotoId) {
        self.controller = controller
        self.currentId = currentId
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        controller.sections
            .sink { [weak self] sections in
                self?.handleSections(sections)
            }
            .store(in: &cancellables)
    }

    private func handleSections(_ sections: [PhotosSection]) {
        ids = sections.flatMap { section in
            section.photos.map { $0.id }
        }
    }

    func getCurrent() -> PhotoId {
        return currentId
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

    private func getId(with delta: Int) -> PhotoId? {
        if let index = ids.firstIndex(of: currentId), ids.indices.contains(index + delta) {
            return ids[index + delta]
        } else {
            return nil
        }
    }
}
