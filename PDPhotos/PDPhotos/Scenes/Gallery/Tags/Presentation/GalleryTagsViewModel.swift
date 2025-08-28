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
import PDCore

protocol GalleryTagsViewModelProtocol: ObservableObject {
    var tags: [PhotoTag] { get }
    var selectedTag: PhotoTag? { get }
    func select(tag: PhotoTag?)
}

final class GalleryTagsViewModel: GalleryTagsViewModelProtocol {
    private let tagsController: GalleryTagsControllerProtocol
    private let listController: PhotosListControllerProtocol
    private let fetchingController: PhotosListFetchingControllerProtocol
    private var cancellables = Set<AnyCancellable>()

    @Published var tags: [PhotoTag] = []
    var selectedTag: PhotoTag? // Intentionally not @Published, otherwise leads to duplicate view updates

    init(
        tagsController: GalleryTagsControllerProtocol,
        listController: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol
    ) {
        self.tagsController = tagsController
        self.listController = listController
        self.fetchingController = fetchingController
        subscribeToUpdates()
        selectedTag = tagsController.getSelectedTag()
        updateTags()
    }

    private func subscribeToUpdates() {
        tagsController.updatePublisher
            .sink { [weak self] in
                self?.updateTags()
            }
            .store(in: &cancellables)
    }

    private func updateTags() {
        let selectedTag = tagsController.getSelectedTag()
        if self.selectedTag != selectedTag {
            self.selectedTag = selectedTag
            let filter = PhotosListFilter(tag: selectedTag)
            fetchingController.setFilter(filter)
            listController.setFilter(filter)
        }
        tags = tagsController.getAvailableTags()
    }

    func select(tag: PhotoTag?) {
        guard selectedTag != tag else {
            return
        }
        if let tag = tag {
            Log.info("[Tag] Select tag: \(tag)", domain: .userAction)
        } else {
            Log.info("[Tag] Select tag: no tag (All)", domain: .userAction)
        }
        selectedTag = tag
        tagsController.select(tag: tag)
        let filter = PhotosListFilter(tag: tag)
        fetchingController.setFilter(filter)
        listController.setFilter(filter)
    }
}
