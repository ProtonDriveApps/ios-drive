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

protocol PhotosGridViewModelProtocol: ObservableObject {
    var sections: [PhotosGridViewSection] { get }
    func didShowLastItem()
}

final class PhotosGridViewModel: PhotosGridViewModelProtocol {
    private let controller: PhotosGalleryController
    private let loadController: PhotosPagingLoadController
    private let monthFormatter: MonthFormatter
    private let durationFormatter: DurationFormatter
    private var cancellables = Set<AnyCancellable>()

    @Published var sections: [PhotosGridViewSection] = []

    init(controller: PhotosGalleryController, loadController: PhotosPagingLoadController, monthFormatter: MonthFormatter, durationFormatter: DurationFormatter) {
        self.controller = controller
        self.monthFormatter = monthFormatter
        self.durationFormatter = durationFormatter
        self.loadController = loadController
        subscribeToUpdates()
    }

    func didShowLastItem() {
        loadController.loadNext()
    }

    private func subscribeToUpdates() {
        controller.sections
            .sink { [weak self] sections in
                self?.handle(sections)
            }
            .store(in: &cancellables)
    }

    private func handle(_ sections: [PhotosSection]) {
        self.sections = sections.map(makeSection)
    }

    private func makeSection(from section: PhotosSection) -> PhotosGridViewSection {
        PhotosGridViewSection(
            title: monthFormatter.formatMonth(from: section.month),
            items: section.photos.map(makePhoto)
        )
    }

    private func makePhoto(from photo: PhotosSection.Photo) -> PhotoGridViewItem {
        PhotoGridViewItem(
            photoId: photo.id.nodeID,
            shareId: photo.id.shareID,
            duration: photo.duration.map { durationFormatter.formatDuration(from: $0) }
        )
    }
}
