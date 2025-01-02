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
import Foundation

protocol PhotosGridViewModelProtocol: ObservableObject {
    var sections: [PhotosGridViewSection] { get }
    var error: PassthroughSubject<Error?, Never> { get }
    var footer: String { get }
    func didShowLastItem()
}

final class PhotosGridViewModel: PhotosGridViewModelProtocol {
    private let controller: PhotosGalleryController
    private let loadController: PhotosPagingLoadController
    private let monthFormatter: MonthFormatter
    private var cancellables = Set<AnyCancellable>()

    @Published var sections: [PhotosGridViewSection] = []
    let error = PassthroughSubject<Error?, Never>()
    let footer: String = "End-to-end encrypted"

    init(controller: PhotosGalleryController, loadController: PhotosPagingLoadController, monthFormatter: MonthFormatter) {
        self.controller = controller
        self.monthFormatter = monthFormatter
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
        
        loadController.errorPublisher
            .sink { [weak self] error in
                Log.error(error, domain: .photosProcessing)
                #if HAS_QA_FEATURES
                self?.error.send(PhotosGridError.failedFetch)
                #endif
            }
            .store(in: &cancellables)
    }
    
    private func handle(_ sections: [PhotosSection]) {
        self.sections = sections.enumerated().map { makeSection(from: $0.element, index: $0.offset) }
    }

    private func makeSection(from section: PhotosSection, index: Int) -> PhotosGridViewSection {
        PhotosGridViewSection(
            title: monthFormatter.formatMonth(from: section.month),
            isFirst: index == 0,
            items: section.photos.map(makePhoto)
        )
    }

    private func makePhoto(from photo: PhotosSection.Photo) -> PhotoGridViewItem {
        PhotoGridViewItem(
            photoId: photo.id.nodeID,
            shareId: photo.id.shareID,
            volumeId: photo.id.volumeID,
            isShared: photo.isShared,
            hasDirectShare: photo.hasDirectShare,
            isVideo: photo.isVideo,
            captureTime: photo.captureTime,
            isDownloading: photo.isDownloading,
            isAvailableOffline: photo.isAvailableOffline,
            burstChildrenCount: photo.burstChildrenCount
        )
    }
}
